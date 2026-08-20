import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../../backend/features/cotizaciones/enum/enum_cotizacion.dart';
import '../../../../../backend/features/motos/modelo/moto.dart';
import '../../../../../backend/features/productos/modelo/producto.dart';
import '../../../../../backend/features/ventas/servicios/modelo/servicio.dart';
import '../../../../../core/resultado.dart';
import '../../../clientes/provider/cliente_provider.dart';
import '../../../motos/provider/motos_provider.dart';
import '../../provider/cotizaciones_provider.dart';
import '../modelo/cotizacion_editor_state.dart';
import '../modelo/item_cotizacion_editor.dart';
import 'guardado_cotizacion.dart';
import 'validacion_cotizacion.dart';

// Notifier

/// Editor de una cotización. Recibe el id por `family`, así que la carga pasa
/// en `build()` y no hace falta el viejo `inicializar()` disparado desde un
/// `addPostFrameCallback` de la vista.
class CotizacionEditorNotifier extends AsyncNotifier<CotizacionEditorState> {
  CotizacionEditorNotifier(this.cotizacionId);

  /// `null` = cotización nueva.
  final int? cotizacionId;

  /// Cuánto se espera desde el último cambio antes de escribir en la base.
  ///
  /// Casi un segundo, no menos: `actualizar` reemplaza todas las líneas de la
  /// cotización, así que guardar en cada tecla del precio sería borrar e
  /// insertar la cotización entera varias veces por segundo.
  static const _retardoGuardado = Duration(milliseconds: 900);

  Timer? _debounce;

  /// Un mes de validez es lo habitual en el taller; se puede cambiar en el
  /// selector de fecha.
  static DateTime get _vigenciaPorDefecto =>
      DateTime.now().add(const Duration(days: 30));

  @override
  Future<CotizacionEditorState> build() async {
    ref.onDispose(() => _debounce?.cancel());
    final id = cotizacionId;
    if (id == null) {
      return CotizacionEditorState(vigenciaHasta: _vigenciaPorDefecto);
    }

    final detalle =
        await ref.read(repositorioCotizacionesProvider).obtenerDetalle(id);
    final resumen = detalle.resumen;

    final cliente = resumen.clienteId == null
        ? null
        : await ref
            .read(repositorioClientesProvider)
            .obtenerPorId(resumen.clienteId!);
    final moto = resumen.motoId == null
        ? null
        : (await ref.read(repositorioMotosProvider).obtenerTodos())
            .where((m) => m.id == resumen.motoId)
            .firstOrNull;

    return CotizacionEditorState(
      cotizacionId: id,
      numero: resumen.numero,
      cliente: cliente,
      moto: moto,
      vigenciaHasta: resumen.vigenciaHasta,
      notas: resumen.notas ?? '',
      descuento: resumen.descuento,
      items: detalle.items
          .map(
            (i) => ItemCotizacionEditor(
              tipo: i.tipoItem,
              referenciaId: i.referenciaId,
              descripcion: i.descripcion,
              cantidad: i.cantidad,
              precioUnitario: i.precioUnitario,
            ),
          )
          .toList(growable: false),
    );
  }

  /// Cambia el estado sin tocar el guardado. Para lo que no se persiste: los
  /// filtros del catálogo de la izquierda.
  void _actualizar(
    CotizacionEditorState Function(CotizacionEditorState actual) cambio,
  ) {
    final actual = state.value;
    if (actual == null) return;
    state = AsyncData(cambio(actual));
  }

  /// Cambia algo que **sí** se guarda, y programa el guardado.
  void _editar(
    CotizacionEditorState Function(CotizacionEditorState actual) cambio,
  ) {
    final actual = state.value;
    if (actual == null) return;
    state = AsyncData(
      cambio(actual).copyWith(
        guardado: EstadoGuardado.pendiente,
        motivoBloqueo: null,
      ),
    );
    _debounce?.cancel();
    _debounce = Timer(_retardoGuardado, guardarAhora);
  }

  // Cabecera

  /// Al elegir una moto se adopta su dueño, salvo que ya haya un cliente
  /// puesto a mano: la moto sabe de quién es y volver a teclearlo sobra.
  Future<void> seleccionarMoto(Moto? moto) async {
    final actual = state.value;
    if (actual == null) return;

    var cliente = actual.cliente;
    if (moto != null && cliente == null) {
      cliente =
          await ref.read(repositorioClientesProvider).obtenerPorId(moto.clienteId);
    }
    _editar((a) => a.copyWith(moto: moto, cliente: cliente));
  }

  void seleccionarCliente(Cliente? cliente) => _editar((a) {
        // Si la moto elegida es de otro dueño, deja de tener sentido.
        final moto =
            a.moto != null && cliente != null && a.moto!.clienteId != cliente.id
                ? null
                : a.moto;
        return a.copyWith(cliente: cliente, moto: moto);
      });

  void cambiarVigencia(DateTime fecha) =>
      _editar((a) => a.copyWith(vigenciaHasta: fecha));

  /// Las notas se teclean en un `TextEditingController` de la vista; esto es
  /// lo que las mete en el estado y dispara el guardado.
  void cambiarNotas(String notas) {
    if (state.value?.notas == notas) return;
    _editar((a) => a.copyWith(notas: notas));
  }

  // Catálogo de la izquierda

  void cambiarTipo(TipoItemCotizacion tipo) => _actualizar(
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

  // Líneas

  void _agregar(ItemCotizacionEditor nuevo) => _editar((a) => a.conItem(nuevo));

  /// El precio sale del catálogo y no se toca: una cotización que se despega
  /// de la lista de precios deja de servir para comparar contra el inventario.
  void agregarProducto(Producto producto) => _agregar(
        ItemCotizacionEditor(
          tipo: TipoItemCotizacion.producto,
          referenciaId: producto.id,
          descripcion: producto.nombre,
          cantidad: 1,
          precioUnitario: producto.precioVenta.round(),
        ),
      );

  /// El servicio entra con su **precio sugerido**, que es de referencia: la
  /// línea se puede ajustar después sin tocar el catálogo, y lo que se cobró
  /// queda en la cotización. Con `0` la línea nace vacía y hay que ponerle
  /// precio antes de guardar.
  void agregarServicio(Servicio servicio) => _agregar(
        ItemCotizacionEditor(
          tipo: TipoItemCotizacion.servicio,
          referenciaId: servicio.id,
          descripcion: servicio.nombre,
          cantidad: 1,
          precioUnitario: servicio.precioSugerido,
        ),
      );

  void agregarLibre({required String descripcion, required int precio}) =>
      _agregar(
        ItemCotizacionEditor(
          tipo: TipoItemCotizacion.libre,
          descripcion: descripcion,
          cantidad: 1,
          precioUnitario: precio,
        ),
      );

  void cambiarCantidad(int indice, double cantidad) =>
      _editar((a) => a.conCantidad(indice, cantidad));

  void cambiarPrecio(int indice, int precio) =>
      _editar((a) => a.conPrecio(indice, precio));

  void eliminarItem(int indice) => _editar((a) => a.sinItem(indice));

  /// El valor se recorta al subtotal en el estado, así que teclear de más no
  /// deja el total en negativo ni llega al `CHECK` de la tabla.
  void cambiarDescuento(int valor) => _editar((a) => a.conDescuento(valor));

  // Persistencia

  /// Guarda ya, sin esperar el retardo.
  ///
  /// La llama el temporizador tras cada cambio, y también la vista antes de
  /// cerrar el editor: si no, el último cambio se perdería con el `Timer`
  /// pendiente.
  ///
  /// Una cotización nueva y **vacía no se crea**: quemaría un consecutivo
  /// `COT-` para nada. Si lo que hay no se puede guardar —una línea sin precio,
  /// una vigencia ya pasada— no se guarda a medias: el estado queda en
  /// [EstadoGuardado.bloqueado] con el motivo, y la barra superior lo dice.
  Future<Resultado> guardarAhora() async {
    _debounce?.cancel();

    final actual = state.value;
    if (actual == null) {
      return const Fallo(
        MotivoFallo.validacion,
        'La cotización todavía se está cargando.',
      );
    }
    if (actual.guardado == EstadoGuardado.guardando) return const Exito();

    if (actual.items.isEmpty && !actual.esEdicion) {
      _actualizar((a) => a.copyWith(guardado: EstadoGuardado.sinCambios));
      return const Exito();
    }

    final invalida = validarCotizacion(
      items: actual.items,
      vigenciaHasta: actual.vigenciaHasta,
    );
    if (invalida != null) {
      _actualizar(
        (a) => a.copyWith(
          guardado: EstadoGuardado.bloqueado,
          motivoBloqueo: switch (invalida) {
            Fallo(:final mensaje) => mensaje,
            Exito() => null,
          },
        ),
      );
      return invalida;
    }

    _actualizar(
      (a) => a.copyWith(
        guardado: EstadoGuardado.guardando,
        motivoBloqueo: null,
      ),
    );

    try {
      final guardada = await GuardadoCotizacion(
        ref.read(repositorioCotizacionesProvider),
      ).guardar(
        id: actual.cotizacionId,
        clienteId: actual.cliente?.id,
        motoId: actual.moto?.id,
        vigenciaHasta: actual.vigenciaHasta,
        notas: actual.notas,
        items: actual.items,
        descuento: actual.descuento,
      );

      if (actual.esEdicion) {
        ref.invalidate(cotizacionDetalleProvider(guardada.id));
      } else {
        // A partir de aquí el editor deja de ser "nueva": los guardados que
        // vengan actualizan esta cotización en vez de crear otra.
        _actualizar(
          (a) => a.copyWith(cotizacionId: guardada.id, numero: guardada.numero),
        );
      }
      _marcarGuardado();
      return const Exito();
    } catch (e) {
      _actualizar(
        (a) => a.copyWith(
          guardado: EstadoGuardado.bloqueado,
          motivoBloqueo: 'No se pudo guardar: $e',
        ),
      );
      return Fallo(MotivoFallo.persistencia, 'No se pudo guardar: $e');
    }
  }

  /// Marca como guardado, salvo que mientras se escribía en la base haya
  /// entrado otro cambio: en ese caso el temporizador ya está corriendo y
  /// decir "guardado" sería mentira.
  void _marcarGuardado() => _actualizar(
        (a) => a.guardado == EstadoGuardado.guardando
            ? a.copyWith(guardado: EstadoGuardado.guardado, motivoBloqueo: null)
            : a,
      );
}

// Providers públicos

/// Editor de la cotización [int?]: `null` abre una nueva.
final cotizacionEditorProvider = AsyncNotifierProvider.autoDispose
    .family<CotizacionEditorNotifier, CotizacionEditorState, int?>(
  CotizacionEditorNotifier.new,
  name: 'cotizacionEditorProvider',
);
