import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/compras/modelo/compra_item.dart';
import '../../../../../backend/features/compras/modelo/compra_resumen.dart';
import '../../../../../backend/features/compras/repositorio/repositorio_compras.dart';
import '../../../../../backend/features/productos/modelo/producto.dart';
import '../../../../../core/resultado.dart';
import '../../provider/compras_providers.dart';
import '../modelo/compra_editor_state.dart';

/// Editor de una remisión.
///
/// Recibe el id por `family` y **siempre existe**: la compra se crea antes de
/// llegar aquí, porque `proveedor_id` es `NOT NULL` y el número sale del
/// consecutivo.
///
/// ## El modelo de guardado
///
/// Es el mismo de órdenes, reservas y deudas, y por el mismo motivo: **anotar
/// una línea mete mercancía al inventario al instante**, así que las
/// escrituras se reparten en dos velocidades.
///
/// - **Agregar o quitar un producto** escribe al instante. Son gestos
///   explícitos y completos.
/// - **Teclear la cantidad o el costo** actualiza la pantalla en el acto y
///   programa la escritura con retardo. Sin eso, cada tecla movería
///   inventario.
///
/// Después de cada escritura —salga bien o mal— se **relee el detalle**: el
/// total de la compra es un caché que calcula el repositorio, y espejarlo en
/// Dart sería inventarse el dato.
class CompraEditorNotifier extends AsyncNotifier<CompraEditorState> {
  CompraEditorNotifier(this.compraId);

  final int compraId;

  /// `late` sin `final`: `build()` se repite y el campo se reasigna.
  late RepositorioCompras _repo;

  /// Cuánto se espera desde la última tecla antes de escribir.
  static const _retardoGuardado = Duration(milliseconds: 450);

  Timer? _debounce;
  final _pendientes = <String>{};
  final _operaciones = <String, Future<Resultado> Function()>{};

  @override
  Future<CompraEditorState> build() async {
    _repo = ref.watch(repositorioComprasProvider);
    ref.onDispose(() => _debounce?.cancel());
    return _desdeDetalle(await _repo.obtenerDetalle(compraId));
  }

  /// Traduce el detalle de la base al estado del editor, conservando lo que es
  /// solo de la interfaz —la búsqueda, la categoría, la página—.
  CompraEditorState _desdeDetalle(
    CompraDetalle detalle, {
    CompraEditorState? conservando,
  }) {
    final c = detalle.resumen;
    return CompraEditorState(
      compraId: c.id,
      numero: c.numero,
      proveedorId: c.proveedorId,
      proveedorNombre: c.proveedorNombre,
      numeroFactura: c.numeroFactura,
      fecha: c.fecha,
      estado: c.estado,
      notas: c.notas,
      total: c.total,
      lineas: detalle.items,
      busquedaCatalogo: conservando?.busquedaCatalogo ?? '',
      categoriaId: conservando?.categoriaId,
      paginaCatalogo: conservando?.paginaCatalogo ?? 0,
      guardado: EstadoGuardadoCompra.guardado,
    );
  }

  void _actualizar(CompraEditorState Function(CompraEditorState a) cambio) {
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
    final detalle = await _repo.obtenerDetalle(compraId);
    if (!ref.mounted) return;
    state = AsyncData(_desdeDetalle(detalle, conservando: actual));
    // Sin `invalidate` del listado: `observarPagina` y `observarResumen` son
    // streams de Drift y re-emiten solos en cuanto cambian las tablas.
  }

  /// La cola de escrituras. **Una detrás de otra, nunca a la vez.**
  ///
  /// Sin esto, tocar cinco veces seguidas una tarjeta del catálogo lanzaba
  /// cinco escrituras concurrentes con sus cinco recargas intercaladas: la
  /// última en responder pisaba a las demás y en pantalla aparecían tres de
  /// las cinco unidades.
  Future<void> _cola = Future<void>.value();

  Future<Resultado> _escribir(Future<Resultado> Function() operacion) {
    final propia = _cola.then((_) => _escribirEnOrden(operacion));
    // El `onError` vacío evita que un fallo rompa la cadena y deje la cola
    // envenenada para todas las siguientes.
    _cola = propia.then((_) {}, onError: (_) {});
    return propia;
  }

  Future<Resultado> _escribirEnOrden(
    Future<Resultado> Function() operacion,
  ) async {
    if (state.value == null) {
      return const Fallo(
        MotivoFallo.validacion,
        'La compra todavía se está cargando.',
      );
    }

    _actualizar((a) => a.copyWith(guardado: EstadoGuardadoCompra.guardando));

    final resultado = await operacion();
    // Se relee también cuando falla: el estado se actualizó de forma optimista
    // antes de escribir, y un rechazo dejaría en pantalla una cantidad que la
    // base no aceptó.
    await _recargar();
    if (!ref.mounted) return resultado;

    if (resultado case Fallo(:final mensaje)) {
      _actualizar(
        (a) => a.copyWith(
          guardado: EstadoGuardadoCompra.bloqueado,
          motivoBloqueo: mensaje,
        ),
      );
    }
    return resultado;
  }

  void _programar(String clave, Future<Resultado> Function() operacion) {
    _pendientes.add(clave);
    _actualizar((a) => a.copyWith(guardado: EstadoGuardadoCompra.pendiente));
    _operaciones[clave] = operacion;

    _debounce?.cancel();
    _debounce = Timer(_retardoGuardado, guardarAhora);
  }

  /// Escribe lo que esté esperando, sin aguardar el retardo.
  ///
  /// La llaman el temporizador, `Ctrl+Enter` y el cierre de la ficha: si no,
  /// el último cambio se perdería junto con el `Timer`.
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

  /// El costo se propone con el último conocido —`productos.precio_compra`, que
  /// es el de la compra anterior— y se teclea encima. Si el producto ya está
  /// en la remisión, el repositorio le suma a su línea.
  Future<Resultado> agregarProducto(Producto producto) {
    final id = producto.id;
    if (id == null) return Future.value(const Exito());

    return _escribir(
      () => _repo.agregarLinea(
        compraId: compraId,
        productoId: id,
        cantidad: 1,
        costoUnitario: producto.precioCompra,
      ),
    );
  }

  void cambiarCantidad(CompraItem linea, double cantidad) {
    if (cantidad <= 0 || cantidad == linea.cantidad) return;
    _actualizar((a) => a.conLinea(_con(linea, cantidad: cantidad)));
    _programar(
      'cantidad-${linea.id}',
      () => _repo.actualizarLinea(linea.id, cantidad: cantidad),
    );
  }

  void cambiarCosto(CompraItem linea, int costo) {
    if (costo < 0 || costo == linea.costoUnitario) return;
    _actualizar((a) => a.conLinea(_con(linea, costo: costo)));
    _programar(
      'costo-${linea.id}',
      () => _repo.actualizarLinea(linea.id, costoUnitario: costo),
    );
  }

  static CompraItem _con(CompraItem linea, {double? cantidad, int? costo}) =>
      CompraItem(
        id: linea.id,
        compraId: linea.compraId,
        productoId: linea.productoId,
        descripcion: linea.descripcion,
        sku: linea.sku,
        imagenUrl: linea.imagenUrl,
        cantidad: cantidad ?? linea.cantidad,
        costoUnitario: costo ?? linea.costoUnitario,
      );

  Future<Resultado> eliminarLinea(CompraItem linea) =>
      _escribir(() => _repo.eliminarLinea(linea.id));

  // ── Cabecera y estado ────────────────────────────────────────────────────

  Future<Resultado> actualizarDatos({
    int? proveedorId,
    DateTime? fecha,
    String? numeroFactura,
    String? notas,
  }) =>
      _escribir(
        () => _repo.actualizarCabecera(
          id: compraId,
          proveedorId: proveedorId,
          fecha: fecha,
          numeroFactura: numeroFactura,
          notas: notas,
        ),
      );

  /// Da la remisión por terminada: deja de admitir líneas y pasa a contar
  /// como gasto del mes. Se guarda antes lo que esté esperando su retardo, o
  /// el último costo tecleado no entraría en el total que se archiva.
  Future<Resultado> terminar() async {
    final pendiente = await guardarAhora();
    if (pendiente case Fallo()) return pendiente;
    return _escribir(() => _repo.terminar(compraId));
  }

  /// Anular saca del inventario lo que había entrado. La compra no se borra:
  /// queda con su número, como una factura anulada.
  Future<Resultado> anular() => _escribir(() => _repo.anular(compraId));

  /// Descarta el borrador en el que no se anotó nada. Lo llama la ficha al
  /// salir, y por eso **no relee**: la compra ya no existe.
  Future<Resultado> descartarVacia() => _repo.descartarVacia(compraId);
}

final compraEditorProvider = AsyncNotifierProvider.autoDispose
    .family<CompraEditorNotifier, CompraEditorState, int>(
  CompraEditorNotifier.new,
  name: 'compraEditorProvider',
);
