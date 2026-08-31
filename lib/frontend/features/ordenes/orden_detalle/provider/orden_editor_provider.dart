import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/productos/modelo/producto.dart';
import '../../../../../backend/features/ordenes/enum/enum_ordenes.dart';
import '../../../../../backend/features/ordenes/modelo/orden_detalle.dart';
import '../../../../../backend/features/servicios/modelo/servicio.dart';
import '../../../../../core/resultado.dart';
import '../../provider/ordenes_providers.dart';
import '../modelo/linea_orden_editor.dart';
import '../modelo/orden_editor_state.dart';
import 'guardado_orden.dart';
import 'validacion_orden.dart';

/// Editor de una orden de servicio.
///
/// Recibe el id por `family` y **siempre existe**: la orden se crea antes de
/// llegar aquí, porque `moto_id` y `cliente_id` son `NOT NULL`.
///
/// ## El modelo de guardado
///
/// Se siente igual que el de cotizaciones —no hay botón de guardar y la barra
/// superior dice en qué punto va— pero escribe distinto (ver [GuardadoOrden]).
/// Las operaciones se reparten en dos velocidades:
///
/// - **Agregar o quitar una línea** escribe al instante, sin retardo. Es un
///   gesto explícito y completo: no hay nada que esperar.
/// - **Teclear** —cantidad, precio, descuento, diagnóstico— actualiza el
///   estado en el acto para que el campo responda, y programa la escritura con
///   un retardo. Sin eso, cada tecla del precio sería un `UPDATE`.
///
/// Después de cada escritura —salga bien o mal— se **relee el detalle** en vez
/// de espejar en Dart lo que hizo el repositorio. Es lo que mantiene honesta
/// la pantalla: los `id` de las líneas nuevas, el descuento que el repositorio
/// recorta solo cuando una línea baja, y la cantidad que el stock no permitió
/// salen de la base y no de una copia. Son cuatro consultas sobre SQLite local con unas decenas
/// de filas; el riesgo de duplicar la lógica de negocio en la vista era mucho
/// más caro (§7 de `CLAUDE.md`).
class OrdenEditorNotifier extends AsyncNotifier<OrdenEditorState> {
  OrdenEditorNotifier(this.ordenId);

  final int ordenId;

  /// Cuánto se espera desde la última tecla antes de escribir.
  ///
  /// Menos que el de cotizaciones (900 ms) porque aquí cada escritura toca
  /// **una** fila, no el documento entero: no hace falta ser tan conservador.
  static const _retardoGuardado = Duration(milliseconds: 450);

  Timer? _debounce;

  /// Qué hay esperando a que venza el retardo. Mientras no esté vacío, una
  /// relectura no puede pisar lo que el usuario está tecleando.
  final _pendientes = <String>{};

  @override
  Future<OrdenEditorState> build() async {
    ref.onDispose(() => _debounce?.cancel());
    final detalle =
        await ref.read(repositorioOrdenesProvider).obtenerDetalle(ordenId);
    return _desdeDetalle(detalle);
  }

  /// Traduce el detalle de la base al estado del editor, conservando lo que es
  /// solo de la interfaz —el tipo activo, la búsqueda, la página—.
  OrdenEditorState _desdeDetalle(
    OrdenDetalle detalle, {
    OrdenEditorState? conservando,
  }) {
    final lineas = <LineaOrdenEditor>[
      for (final tarea in detalle.tareas)
        LineaOrdenEditor(
          id: tarea.id,
          tipo: TipoLineaOrden.servicio,
          referenciaId: tarea.servicioId,
          tecnicoId: tarea.tecnicoId,
          tecnicoNombre: tarea.tecnicoNombre,
          descripcion: tarea.servicioNombre,
          cantidad: 1,
          precioUnitario: tarea.precioPactado,
          completado: tarea.completado,
        ),
      for (final repuesto in detalle.repuestos)
        LineaOrdenEditor(
          id: repuesto.id,
          tipo: TipoLineaOrden.repuesto,
          referenciaId: repuesto.productoId,
          descripcion: repuesto.productoNombre,
          cantidad: repuesto.cantidad,
          precioUnitario: repuesto.precioUnitario,
        ),
      for (final cargo in detalle.cargos)
        LineaOrdenEditor(
          id: cargo.id,
          tipo: TipoLineaOrden.cargo,
          descripcion: cargo.descripcion,
          cantidad: 1,
          precioUnitario: cargo.precio,
        ),
    ];

    return OrdenEditorState(
      ordenId: detalle.id,
      numero: detalle.numeroOrden,
      clienteId: detalle.clienteId,
      clienteNombre: detalle.clienteNombre,
      motoId: detalle.motoId,
      motoDescripcion: detalle.motoDescripcion,
      motoPlaca: detalle.motoPlaca,
      kilometrajeEntrada: detalle.kilometrajeEntrada,
      estado: detalle.estado,
      diagnostico: detalle.diagnosticoCliente ?? '',
      observaciones: detalle.observacionesMecanico ?? '',
      descuento: detalle.descuento,
      lineas: lineas,
      guardado: EstadoGuardadoOrden.guardado,
      tipoActivo: conservando?.tipoActivo ?? TipoLineaOrden.repuesto,
      busquedaCatalogo: conservando?.busquedaCatalogo ?? '',
      categoriaId: conservando?.categoriaId,
      paginaCatalogo: conservando?.paginaCatalogo ?? 0,
    );
  }

  GuardadoOrden get _guardado =>
      GuardadoOrden(ref.read(repositorioOrdenesProvider));

  /// Cambia el estado sin tocar el guardado. Para lo que no se persiste: los
  /// filtros del catálogo de la izquierda.
  void _actualizar(
    OrdenEditorState Function(OrdenEditorState actual) cambio,
  ) {
    final actual = state.value;
    if (actual == null) return;
    state = AsyncData(cambio(actual));
  }

  /// Relee el detalle y lo pone en pantalla.
  ///
  /// Si hay algo esperando su retardo, **no se relee**: pisaría lo que el
  /// usuario está tecleando con el valor viejo de la base. La escritura
  /// pendiente hará su propia relectura cuando termine.
  Future<void> _recargar() async {
    if (_pendientes.isNotEmpty) return;
    final actual = state.value;
    final detalle =
        await ref.read(repositorioOrdenesProvider).obtenerDetalle(ordenId);
    if (!ref.mounted) return;
    state = AsyncData(_desdeDetalle(detalle, conservando: actual));
    // El listado y sus contadores miran las mismas tablas.
    ref.invalidate(ordenesResumenProvider);
  }

  /// Ejecuta una escritura inmediata: marca «guardando», escribe, relee.
  ///
  /// Devuelve el fallo en vez de lanzarlo: el editor tiene que seguir en pie
  /// aunque el stock no alcance, con el motivo a la vista.
  /// La cola de escrituras. **Una detrás de otra, nunca a la vez.**
  ///
  /// Sin esto, tocar cinco veces seguidas una tarjeta del catálogo lanzaba
  /// cinco escrituras concurrentes con sus cinco recargas intercaladas: la
  /// última en responder pisaba a las demás y en pantalla aparecían tres de
  /// las cinco unidades. El usuario lo veía como que «se buguea al clickear
  /// rápido», y es de los fallos que no se reproducen despacio.
  ///
  /// Encadenar es suficiente y es lo correcto: son escrituras del mismo
  /// documento, y el orden en que el usuario las pidió es el orden en que
  /// tienen que quedar.
  Future<void> _cola = Future<void>.value();

  Future<Resultado> _escribir(Future<void> Function() operacion) {
    // Se encola antes de nada para que dos llamadas seguidas no puedan
    // colarse entre el `await` y la asignación.
    final propia = _cola.then((_) => _escribirEnOrden(operacion));
    // El `onError` vacío evita que un fallo de una escritura rompa la cadena
    // y deje la cola envenenada para todas las siguientes.
    _cola = propia.then((_) {}, onError: (_) {});
    return propia;
  }

  Future<Resultado> _escribirEnOrden(Future<void> Function() operacion) async {
    final actual = state.value;
    if (actual == null) {
      return const Fallo(
        MotivoFallo.validacion,
        'La orden todavía se está cargando.',
      );
    }

    _actualizar(
      (a) => a.copyWith(
        guardado: EstadoGuardadoOrden.guardando,
        motivoBloqueo: null,
      ),
    );

    try {
      await operacion();
      await _recargar();
      return const Exito();
    } catch (e) {
      final mensaje = mensajeDeExcepcion(e);
      // Releer **también** cuando falla. El estado se actualizó de forma
      // optimista antes de escribir, así que un rechazo por falta de stock
      // dejaría en pantalla una cantidad que la base no aceptó: el panel
      // mostraría doce unidades que el taller no tiene y el total mentiría.
      // La relectura devuelve la línea a lo que de verdad quedó guardado.
      await _recargar();
      if (!ref.mounted) return Fallo(MotivoFallo.persistencia, mensaje);
      _actualizar(
        (a) => a.copyWith(
          guardado: EstadoGuardadoOrden.bloqueado,
          motivoBloqueo: mensaje,
        ),
      );
      return Fallo(MotivoFallo.persistencia, mensaje);
    }
  }

  /// Programa una escritura con retardo, marcando qué es lo que espera.
  ///
  /// [clave] identifica el campo: dos ediciones seguidas del mismo precio se
  /// pisan, pero cambiar el precio y después el diagnóstico deja los dos
  /// pendientes. Al vencer el retardo se escriben todos juntos.
  void _programar(String clave, Future<void> Function() operacion) {
    _pendientes.add(clave);
    _actualizar(
      (a) => a.copyWith(
        guardado: EstadoGuardadoOrden.pendiente,
        motivoBloqueo: null,
      ),
    );
    _operaciones[clave] = operacion;

    _debounce?.cancel();
    _debounce = Timer(_retardoGuardado, guardarAhora);
  }

  final _operaciones = <String, Future<void> Function()>{};

  /// Escribe lo que esté esperando, sin aguardar el retardo.
  ///
  /// La llama el temporizador, `Ctrl+Enter` y el cierre del editor: si no, el
  /// último cambio se perdería junto con el `Timer`.
  Future<Resultado> guardarAhora() async {
    _debounce?.cancel();
    if (_operaciones.isEmpty) return const Exito();

    final pendientes = List.of(_operaciones.values);
    _operaciones.clear();
    _pendientes.clear();

    return _escribir(() async {
      for (final operacion in pendientes) {
        await operacion();
      }
    });
  }

  // Catálogo de la izquierda — nada de esto se persiste.

  void cambiarTipo(TipoLineaOrden tipo) => _actualizar(
        (a) => a.copyWith(
          tipoActivo: tipo,
          busquedaCatalogo: '',
          paginaCatalogo: 0,
        ),
      );

  /// Buscar y filtrar **vuelven a la primera página**: quedarse en la cuarta
  /// después de acotar el catálogo deja la rejilla vacía sin explicar por qué.
  void buscarEnCatalogo(String texto) => _actualizar(
        (a) => a.copyWith(busquedaCatalogo: texto.trim(), paginaCatalogo: 0),
      );

  void filtrarPorCategoria(int? categoriaId) => _actualizar(
        (a) => a.copyWith(categoriaId: categoriaId, paginaCatalogo: 0),
      );

  void irAPaginaCatalogo(int pagina) =>
      _actualizar((a) => a.copyWith(paginaCatalogo: pagina < 0 ? 0 : pagina));

  // Alta de líneas — escriben al instante, sin retardo.

  /// El precio sale del catálogo. Si el mismo producto ya está en la orden se
  /// **suma a su línea** en vez de abrir otra, igual que en el punto de venta.
  Future<Resultado> agregarProducto(Producto producto) async {
    final actual = state.value;
    final id = producto.id;
    if (actual == null || id == null) return const Exito();

    final existente = actual.lineas
        .where((l) => l.tipo == TipoLineaOrden.repuesto && l.referenciaId == id)
        .firstOrNull;

    if (existente != null) {
      return _escribir(
        () => _guardado.cambiarCantidad(existente, existente.cantidad + 1),
      );
    }

    return _escribir(
      () => _guardado.agregarRepuesto(
        ordenId: ordenId,
        productoId: id,
        cantidad: 1,
        precioUnitario: producto.precioVenta,
      ),
    );
  }

  /// El servicio entra ya completo: con su técnico y su precio.
  ///
  /// A diferencia de cotizaciones, la línea **no puede nacer a medias**:
  /// `ordenes_tareas.tecnico_id` es `NOT NULL`. Por eso los dos campos se
  /// completan en el panel izquierdo, antes de que la línea cruce a la orden.
  Future<Resultado> agregarServicio(
    Servicio servicio, {
    required int tecnicoId,
    required int precio,
  }) =>
      _escribir(
        () => _guardado.agregarServicio(
          ordenId: ordenId,
          servicioId: servicio.id,
          tecnicoId: tecnicoId,
          precio: precio,
        ),
      );

  Future<Resultado> agregarCargo({
    required String descripcion,
    required int precio,
  }) =>
      _escribir(
        () => _guardado.agregarCargo(
          ordenId: ordenId,
          descripcion: descripcion,
          precio: precio,
        ),
      );

  Future<Resultado> eliminarLinea(LineaOrdenEditor linea) =>
      _escribir(() => _guardado.eliminarLinea(linea));

  Future<Resultado> marcarCompletada(
    LineaOrdenEditor linea, {
    required bool hecha,
  }) =>
      _escribir(() => _guardado.marcarCompletada(linea, hecha: hecha));

  // Edición de líneas — responden en el acto y escriben con retardo.

  void cambiarCantidad(LineaOrdenEditor linea, double cantidad) {
    if (cantidad < 1 || cantidad == linea.cantidad) return;
    final editada = linea.copyWith(cantidad: cantidad);
    _actualizar((a) => a.conLinea(editada));
    _programar(
      'cantidad-${linea.tipo.name}-${linea.id}',
      () => _guardado.cambiarCantidad(editada, cantidad),
    );
  }

  void cambiarPrecio(LineaOrdenEditor linea, int precio) {
    if (precio < 0 || precio == linea.precioUnitario) return;
    final editada = linea.copyWith(precioUnitario: precio);
    _actualizar((a) => a.conLinea(editada));
    _programar(
      'precio-${linea.tipo.name}-${linea.id}',
      () => _guardado.cambiarPrecio(editada, precio),
    );
  }

  /// El recorte al subtotal lo hace el repositorio, así que el valor que se
  /// muestra puede quedar por encima un instante; la relectura lo corrige.
  void cambiarDescuento(int valor) {
    final ajustado = valor < 0 ? 0 : valor;
    if (state.value?.descuento == ajustado) return;
    _actualizar((a) => a.copyWith(descuento: ajustado));
    _programar(
      'descuento',
      () => _guardado.fijarDescuento(ordenId: ordenId, valor: ajustado),
    );
  }

  // Cabecera

  void cambiarKilometraje(int kilometraje) {
    if (state.value?.kilometrajeEntrada == kilometraje) return;
    _actualizar((a) => a.copyWith(kilometrajeEntrada: kilometraje));
    _programarCabecera();
  }

  void cambiarDiagnostico(String texto) {
    if (state.value?.diagnostico == texto) return;
    _actualizar((a) => a.copyWith(diagnostico: texto));
    _programarCabecera();
  }

  void cambiarObservaciones(String texto) {
    if (state.value?.observaciones == texto) return;
    _actualizar((a) => a.copyWith(observaciones: texto));
    _programarCabecera();
  }

  /// Los tres campos de texto de la cabecera comparten una sola escritura:
  /// `actualizar` los manda juntos de todos modos.
  void _programarCabecera() => _programar('cabecera', () {
        final a = state.value;
        if (a == null) return Future<void>.value();
        return _guardado.guardarCabecera(
          ordenId: ordenId,
          estado: a.estado,
          kilometrajeEntrada: a.kilometrajeEntrada,
          motoId: a.motoId,
          clienteId: a.clienteId,
          diagnostico: a.diagnostico,
          observaciones: a.observaciones,
        );
      });

  /// Cambia el estado de la orden. **No espera el retardo**: cerrar una orden
  /// mueve el inventario entero, y eso no es algo que deba pasar «en un
  /// momento» mientras el usuario mira otra cosa.
  ///
  /// Si el stock no alcanza, el repositorio revierte la transacción y la orden
  /// se queda como estaba: el fallo llega con el nombre del repuesto que
  /// faltó.
  Future<Resultado> cambiarEstado(EstadoOrden nuevo) async {
    final actual = state.value;
    if (actual == null || actual.estado == nuevo) return const Exito();

    final invalido =
        validarCambioEstado(desde: actual.estado, hacia: nuevo);
    if (invalido != null) return _bloquear(invalido);

    final cierra =
        nuevo == EstadoOrden.lista || nuevo == EstadoOrden.entregada;
    if (cierra) {
      final falta = validarCierre(lineas: actual.lineas);
      if (falta != null) return _bloquear(falta);
    }

    // Lo que esté a medio teclear se escribe antes: si no, `actualizar`
    // mandaría el diagnóstico viejo y pisaría lo tecleado.
    await guardarAhora();

    return _escribir(
      () => _guardado.guardarCabecera(
        ordenId: ordenId,
        estado: nuevo,
        kilometrajeEntrada: actual.kilometrajeEntrada,
        motoId: actual.motoId,
        clienteId: actual.clienteId,
        diagnostico: actual.diagnostico,
        observaciones: actual.observaciones,
      ),
    );
  }

  /// Anula la orden: devuelve al inventario lo que ya había salido y conserva
  /// el número y el historial. No se borra —una orden es un registro de
  /// trabajo, igual que una factura (§12 de `REGLAS_BD.md`).
  Future<Resultado> anular() => cambiarEstado(EstadoOrden.anulada);

  Resultado _bloquear(Resultado fallo) {
    if (fallo case Fallo(:final mensaje)) {
      _actualizar(
        (a) => a.copyWith(
          guardado: EstadoGuardadoOrden.bloqueado,
          motivoBloqueo: mensaje,
        ),
      );
    }
    return fallo;
  }
}

/// Editor de la orden [int]. A diferencia del de cotizaciones no acepta
/// `null`: la orden se crea antes de abrir el editor.
final ordenEditorProvider = AsyncNotifierProvider.autoDispose
    .family<OrdenEditorNotifier, OrdenEditorState, int>(
  OrdenEditorNotifier.new,
  name: 'ordenEditorProvider',
);
