import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/compras/enum/enum_compras.dart';
import '../../../../backend/features/compras/modelo/compra_item.dart';
import '../../../../backend/features/compras/modelo/compra_resumen.dart';
import '../../../../backend/features/compras/repositorio/repositorio_compras.dart';
import '../../../../backend/features/compras/repositorio/repositorio_compras_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../autenticacion/provider/auth_providers.dart';

/// El repositorio de las compras. La sesión entra **por el constructor**: es
/// una dependencia visible, no un registro global (`CLAUDE.md` §3).
final repositorioComprasProvider = Provider<RepositorioCompras>(
  name: 'repositorioComprasProvider',
  (ref) => RepositorioComprasImpl(
    ref.watch(appDatabaseProvider),
    ref.watch(sesionActualProvider),
  ),
);

/// Estado del listado: **solo la página visible**, más lo que hace falta para
/// pintar el paginador y saber qué filtros están puestos.
final class ComprasState {
  const ComprasState({
    this.items = const [],
    this.total = 0,
    this.suma = 0,
    this.pagina = 0,
    this.tamanoPagina = 15,
    this.busqueda = '',
    this.proveedorId,
    this.estado,
    this.desde,
    this.hasta,
  });

  final List<CompraResumen> items;
  final int total;

  /// Lo que costó **todo** lo que cumple el filtro, no lo de esta página. Lo
  /// suma SQLite con el mismo `WHERE` del listado.
  final int suma;

  final int pagina;
  final int tamanoPagina;

  final String busqueda;
  final int? proveedorId;
  final EstadoCompra? estado;
  final DateTime? desde;
  final DateTime? hasta;

  int get totalPaginas =>
      total <= 0 ? 1 : (total + tamanoPagina - 1) ~/ tamanoPagina;

  bool get hayFiltro => filtro.hayFiltro;

  FiltroCompras get filtro => FiltroCompras(
        busqueda: busqueda,
        proveedorId: proveedorId,
        estado: estado,
        desde: desde,
        hasta: hasta,
      );

  /// Los campos que se pueden **quitar** llevan un `bool` aparte: con solo el
  /// valor nulo no habría forma de distinguir «no lo cambies» de «bórralo».
  ComprasState copyWith({
    List<CompraResumen>? items,
    int? total,
    int? suma,
    int? pagina,
    String? busqueda,
    int? proveedorId,
    bool limpiarProveedor = false,
    EstadoCompra? estado,
    bool limpiarEstado = false,
    DateTime? desde,
    bool limpiarDesde = false,
    DateTime? hasta,
    bool limpiarHasta = false,
  }) =>
      ComprasState(
        items: items ?? this.items,
        total: total ?? this.total,
        suma: suma ?? this.suma,
        pagina: pagina ?? this.pagina,
        tamanoPagina: tamanoPagina,
        busqueda: busqueda ?? this.busqueda,
        proveedorId:
            limpiarProveedor ? null : (proveedorId ?? this.proveedorId),
        estado: limpiarEstado ? null : (estado ?? this.estado),
        desde: limpiarDesde ? null : (desde ?? this.desde),
        hasta: limpiarHasta ? null : (hasta ?? this.hasta),
      );
}

class ComprasNotifier extends AsyncNotifier<ComprasState> {
  /// `late` **sin `final`**: Riverpod conserva la instancia del notifier y
  /// vuelve a llamar a `build()` cuando el provider se invalida.
  late RepositorioCompras _repo;
  StreamSubscription<PaginaCompras>? _sub;

  @override
  Future<ComprasState> build() async {
    _repo = ref.watch(repositorioComprasProvider);
    ref.onDispose(() => _sub?.cancel());

    const inicial = ComprasState();
    final primera = await _repo
        .observarPagina(
          filtro: inicial.filtro,
          pagina: inicial.pagina,
          tamano: inicial.tamanoPagina,
        )
        .first;

    _suscribir(inicial);
    return inicial.copyWith(
      items: primera.items,
      total: primera.total,
      suma: primera.suma,
    );
  }

  /// Reabre el stream con los filtros y la página vigentes. Cada cambio de
  /// filtro es una consulta nueva, no un recorte en memoria.
  void _suscribir(ComprasState estado) {
    _sub?.cancel();
    _sub = _repo
        .observarPagina(
          filtro: estado.filtro,
          pagina: estado.pagina,
          tamano: estado.tamanoPagina,
        )
        .listen(
      (pagina) {
        final actual = state.value;
        if (actual == null) return;
        state = AsyncData(
          actual.copyWith(
            items: pagina.items,
            total: pagina.total,
            suma: pagina.suma,
          ),
        );
      },
      onError: (Object e, StackTrace st) => state = AsyncError(e, st),
    );
  }

  void _aplicar(ComprasState nuevo) {
    state = AsyncData(nuevo);
    _suscribir(nuevo);
  }

  // Todo filtro vuelve a la primera página: el conjunto pasó a ser otro.

  void buscar(String texto) {
    final actual = state.value;
    if (actual == null) return;
    final limpio = texto.trim();
    if (actual.busqueda == limpio) return;
    _aplicar(actual.copyWith(busqueda: limpio, pagina: 0));
  }

  /// Tocar el valor ya activo lo quita: el mismo gesto pone y saca.
  void filtrarPorEstado(EstadoCompra? estado) {
    final actual = state.value;
    if (actual == null) return;
    final quitar = estado == null || actual.estado == estado;
    _aplicar(actual.copyWith(
      estado: quitar ? null : estado,
      limpiarEstado: quitar,
      pagina: 0,
    ));
  }

  void filtrarPorProveedor(int? proveedorId) {
    final actual = state.value;
    if (actual == null) return;
    _aplicar(actual.copyWith(
      proveedorId: proveedorId,
      limpiarProveedor: proveedorId == null,
      pagina: 0,
    ));
  }

  /// El rango es inclusivo, así que [hasta] se estira al final del día: con la
  /// medianoche, pedir «hasta hoy» dejaría fuera lo que llegó hoy.
  void filtrarPorFechas({DateTime? desde, DateTime? hasta}) {
    final actual = state.value;
    if (actual == null) return;
    _aplicar(actual.copyWith(
      desde:
          desde == null ? null : DateTime(desde.year, desde.month, desde.day),
      limpiarDesde: desde == null,
      hasta: hasta == null
          ? null
          : DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59, 999),
      limpiarHasta: hasta == null,
      pagina: 0,
    ));
  }

  void limpiarFiltros() {
    final actual = state.value;
    if (actual == null || !actual.hayFiltro) return;
    _aplicar(const ComprasState());
  }

  void irAPagina(int pagina) {
    final actual = state.value;
    if (actual == null || pagina == actual.pagina) return;
    if (pagina < 0 || pagina >= actual.totalPaginas) return;
    _aplicar(actual.copyWith(pagina: pagina));
  }
}

final comprasProvider = AsyncNotifierProvider<ComprasNotifier, ComprasState>(
  ComprasNotifier.new,
  name: 'comprasProvider',
);

/// Las compras de la página actual.
final comprasPaginaProvider = Provider<List<CompraResumen>>(
  name: 'comprasPaginaProvider',
  (ref) => ref.watch(comprasProvider).value?.items ?? const [],
);

/// Los cuatro contadores del encabezado, sobre el mes en curso.
final resumenComprasProvider = StreamProvider<ResumenCompras>(
  name: 'resumenComprasProvider',
  (ref) => ref.watch(repositorioComprasProvider).observarResumen(),
);

/// La remisión abierta, con sus líneas.
final compraDetalleProvider =
    FutureProvider.autoDispose.family<CompraDetalle, int>(
  name: 'compraDetalleProvider',
  (ref, id) => ref.watch(repositorioComprasProvider).obtenerDetalle(id),
);

/// Lo último que se compró de un producto, para su ficha: «última compra hace
/// 12 días, a $6.500». Sale de `compra_detalles`, no de `precio_compra`.
final ultimaCompraProvider =
    StreamProvider.autoDispose.family<UltimaCompra?, int>(
  name: 'ultimaCompraProvider',
  (ref, productoId) =>
      ref.watch(repositorioComprasProvider).observarUltimaCompra(productoId),
);

/// Cuánto se le lleva comprado a un proveedor, para su ficha.
final resumenProveedorComprasProvider =
    StreamProvider.autoDispose.family<ResumenProveedorCompras, int>(
  name: 'resumenProveedorComprasProvider',
  (ref, proveedorId) => ref
      .watch(repositorioComprasProvider)
      .observarResumenProveedor(proveedorId),
);
