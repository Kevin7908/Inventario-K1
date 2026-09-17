import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/productos/modelo/producto.dart';
import '../../../../../backend/features/reservas/enum/enum_reserva.dart';
import '../../../../../backend/features/reservas/modelo/reserva_detalle.dart';
import '../../../../../backend/features/reservas/modelo/reserva_item.dart';
import '../../../../../backend/features/reservas/repositorio/repositorio_reservas.dart';
import '../../../../../backend/share/dominio/metodo_pago.dart';
import '../../../../../core/resultado.dart';
import '../../provider/reservas_providers.dart';
import '../modelo/reserva_editor_state.dart';

/// Editor de una reserva.
///
/// Recibe el id por `family` y **siempre existe**: la reserva se crea antes de
/// llegar aquí, porque `cliente_id` es `NOT NULL`.
///
/// ## El modelo de guardado
///
/// Igual que el de órdenes, y por el mismo motivo: apartar mercancía descuenta
/// stock al instante, así que las escrituras se reparten en dos velocidades.
///
/// - **Agregar o quitar una línea, y registrar un abono**, escriben al
///   instante. Son gestos explícitos y completos.
/// - **Teclear la cantidad** actualiza la pantalla en el acto y programa la
///   escritura con retardo. Sin eso, cada tecla movería inventario.
///
/// Después de cada escritura —salga bien o mal— se **relee el detalle**. Los
/// dos cachés de la reserva (`total_reserva` y `pagado_acumulado`) los calcula
/// el repositorio, y una devolución automática puede cambiar el pagado sin que
/// la vista lo pidiera: espejarlo en Dart sería inventarse el dato.
class ReservaEditorNotifier extends AsyncNotifier<ReservaEditorState> {
  ReservaEditorNotifier(this.reservaId);

  final int reservaId;

  /// `late` sin `final`: `build()` se repite y el campo se reasigna.
  late RepositorioReservas _repo;

  /// Cuánto se espera desde la última tecla antes de escribir.
  static const _retardoGuardado = Duration(milliseconds: 450);

  Timer? _debounce;
  final _pendientes = <String>{};
  final _operaciones = <String, Future<Resultado> Function()>{};

  @override
  Future<ReservaEditorState> build() async {
    _repo = ref.watch(repositorioReservasProvider);
    ref.onDispose(() => _debounce?.cancel());
    return _desdeDetalle(await _repo.obtenerDetalle(reservaId));
  }

  /// Traduce el detalle de la base al estado del editor, conservando lo que es
  /// solo de la interfaz —el panel activo, la búsqueda, la página—.
  ReservaEditorState _desdeDetalle(
    ReservaDetalle detalle, {
    ReservaEditorState? conservando,
  }) {
    final r = detalle.resumen;
    return ReservaEditorState(
      reservaId: r.id,
      numero: r.numero,
      clienteNombre: r.nombreCliente,
      motoDescripcion: r.nombreMoto,
      motoPlaca: r.placaMoto,
      cotizacionId: r.cotizacionId,
      estado: r.estado,
      fechaLimite: r.fechaLimite,
      totalReserva: r.totalReserva,
      pagadoAcumulado: r.pagadoAcumulado,
      lineas: detalle.items,
      // De la más reciente a la más vieja: lo último que pasó es lo que se
      // consulta, y lo viejo queda abajo.
      abonos: [...detalle.abonos]
        ..sort((a, b) => b.fechaPago.compareTo(a.fechaPago)),
      seccionActiva: conservando?.seccionActiva ?? SeccionReserva.productos,
      busquedaCatalogo: conservando?.busquedaCatalogo ?? '',
      categoriaId: conservando?.categoriaId,
      paginaCatalogo: conservando?.paginaCatalogo ?? 0,
      guardado: EstadoGuardadoReserva.guardado,
    );
  }

  void _actualizar(
    ReservaEditorState Function(ReservaEditorState actual) cambio,
  ) {
    final actual = state.value;
    if (actual == null) return;
    state = AsyncData(cambio(actual));
  }

  /// Relee el detalle y lo pone en pantalla.
  ///
  /// Si hay algo esperando su retardo **no se relee**: pisaría lo que el
  /// usuario está tecleando con el valor viejo de la base.
  Future<void> _recargar() async {
    if (_pendientes.isNotEmpty) return;
    final actual = state.value;
    final detalle = await _repo.obtenerDetalle(reservaId);
    if (!ref.mounted) return;
    state = AsyncData(_desdeDetalle(detalle, conservando: actual));
    // Sin `invalidate` del listado: `observarPagina` es un stream de Drift y
    // re-emite solo en cuanto cambian las tablas. Invalidarlo no lo refrescaba
    // antes, solo forzaba una segunda pasada por `build()`.
  }

  /// Ejecuta una escritura inmediata: marca «guardando», escribe, relee.
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

  Future<Resultado> _escribir(Future<Resultado> Function() operacion) {
    // Se encola antes de nada para que dos llamadas seguidas no puedan
    // colarse entre el `await` y la asignación.
    final propia = _cola.then((_) => _escribirEnOrden(operacion));
    // El `onError` vacío evita que un fallo de una escritura rompa la cadena
    // y deje la cola envenenada para todas las siguientes.
    _cola = propia.then((_) {}, onError: (_) {});
    return propia;
  }

  Future<Resultado> _escribirEnOrden(Future<Resultado> Function() operacion) async {
    if (state.value == null) {
      return const Fallo(
        MotivoFallo.validacion,
        'La reserva todavía se está cargando.',
      );
    }

    _actualizar(
      (a) => a.copyWith(guardado: EstadoGuardadoReserva.guardando),
    );

    final resultado = await operacion();
    // Se relee también cuando falla: el estado se actualizó de forma optimista
    // antes de escribir, y un rechazo dejaría en pantalla una cantidad que la
    // base no aceptó.
    await _recargar();
    if (!ref.mounted) return resultado;

    if (resultado case Fallo(:final mensaje)) {
      _actualizar(
        (a) => a.copyWith(
          guardado: EstadoGuardadoReserva.bloqueado,
          motivoBloqueo: mensaje,
        ),
      );
    }
    return resultado;
  }

  void _programar(String clave, Future<Resultado> Function() operacion) {
    _pendientes.add(clave);
    _actualizar((a) => a.copyWith(guardado: EstadoGuardadoReserva.pendiente));
    _operaciones[clave] = operacion;

    _debounce?.cancel();
    _debounce = Timer(_retardoGuardado, guardarAhora);
  }

  /// Escribe lo que esté esperando, sin aguardar el retardo.
  ///
  /// La llaman el temporizador, `Ctrl+Enter` y el cierre del editor: si no, el
  /// último cambio se perdería junto con el `Timer`.
  Future<Resultado> guardarAhora() async {
    _debounce?.cancel();
    if (_operaciones.isEmpty) return const Exito();

    final pendientes = List.of(_operaciones.values);
    _operaciones.clear();
    _pendientes.clear();

    return _escribir(() async {
      for (final operacion in pendientes) {
        final r = await operacion();
        if (r case Fallo()) return r;
      }
      return const Exito();
    });
  }

  // ── Panel izquierdo: nada de esto se persiste ────────────────────────────

  void cambiarSeccion(SeccionReserva panel) =>
      _actualizar((a) => a.copyWith(seccionActiva: panel));

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

  // ── Líneas ───────────────────────────────────────────────────────────────

  /// El precio sale del catálogo. Si el producto ya está apartado, el
  /// repositorio suma a su línea en vez de abrir otra.
  Future<Resultado> agregarProducto(Producto producto) {
    final id = producto.id;
    if (id == null) return Future.value(const Exito());

    return _escribir(
      () => _repo.agregarItem(
        reservaId: reservaId,
        productoId: id,
        cantidad: 1,
        precioUnitario: producto.precioVenta.round(),
      ),
    );
  }

  void cambiarCantidad(ReservaItem linea, double cantidad) {
    if (cantidad < 1 || cantidad == linea.cantidad) return;
    _actualizar((a) => a.conLinea(_conCantidad(linea, cantidad)));
    _programar(
      'cantidad-${linea.id}',
      () => _repo.actualizarItem(linea.id, cantidad: cantidad),
    );
  }

  static ReservaItem _conCantidad(ReservaItem linea, double cantidad) =>
      ReservaItem(
        id: linea.id,
        reservaId: linea.reservaId,
        productoId: linea.productoId,
        nombreProducto: linea.nombreProducto,
        sku: linea.sku,
        imagenUrl: linea.imagenUrl,
        cantidad: cantidad,
        precioUnitario: linea.precioUnitario,
      );

  Future<Resultado> eliminarLinea(ReservaItem linea) =>
      _escribir(() => _repo.eliminarItem(linea.id));

  // ── Dinero y estado ──────────────────────────────────────────────────────

  Future<Resultado> registrarAbono({
    required int monto,
    required MetodoPago metodoPago,
    String? referencia,
  }) =>
      _escribir(() async {
        try {
          await _repo.registrarAbono(
            reservaId: reservaId,
            monto: monto,
            metodoPago: metodoPago,
            referenciaPago: referencia,
          );
          return const Exito();
        } catch (e) {
          return Fallo(
            MotivoFallo.persistencia,
            e.toString().replaceFirst('Exception: ', ''),
          );
        }
      });

  Future<Resultado> cambiarEstado(EstadoReserva nuevo) =>
      _escribir(() async {
        try {
          await _repo.cambiarEstado(reservaId, nuevo);
          return const Exito();
        } catch (e) {
          return Fallo(
            MotivoFallo.persistencia,
            e.toString().replaceFirst('Exception: ', ''),
          );
        }
      });
}

final reservaEditorProvider = AsyncNotifierProvider.autoDispose
    .family<ReservaEditorNotifier, ReservaEditorState, int>(
  ReservaEditorNotifier.new,
  name: 'reservaEditorProvider',
);
