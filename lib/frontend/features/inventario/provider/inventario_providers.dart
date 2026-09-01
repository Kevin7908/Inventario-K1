import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/inventario/modelo/movimiento_detalle.dart';
import '../../../../backend/features/inventario/modelo/movimiento_inventario.dart';
import '../../../../backend/features/inventario/repositorio/repositorio_inventario.dart';
import '../../../../backend/features/inventario/repositorio/repositorio_inventario_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../autenticacion/provider/auth_providers.dart';

/// El **único** camino por el que la interfaz mueve stock.
///
/// Cualquier pantalla que necesite sumar o restar existencias pasa por aquí:
/// el repositorio escribe el renglón del libro mayor y el caché de
/// `productos.stock_actual` en la misma transacción.
final repositorioInventarioProvider = Provider<RepositorioInventario>(
  name: 'repositorioInventarioProvider',
  (ref) => RepositorioInventarioImpl(
    ref.watch(appDatabaseProvider),
    // Quién firma lo que este repositorio escriba. Es una dependencia del
    // constructor, no un registro global (`CLAUDE.md` §3).
    ref.watch(sesionActualProvider),
  ),
);

/// Los últimos movimientos de un producto, para su ficha.
///
/// El `limite` lo resuelve SQL: un aceite que se vende a diario tiene miles de
/// renglones y la ficha muestra los últimos ocho.
final movimientosDeProductoProvider =
    StreamProvider.autoDispose.family<List<MovimientoInventario>, int>(
  name: 'movimientosDeProductoProvider',
  (ref, productoId) => ref
      .watch(repositorioInventarioProvider)
      .observarPorProducto(productoId, limite: 8),
);

/// Estado del kardex: **solo la página visible**, más lo que hace falta para
/// pintar el paginador y saber qué filtros están puestos.
final class MovimientosState {
  const MovimientosState({
    this.items = const [],
    this.total = 0,
    this.pagina = 0,
    this.tamanoPagina = 15,
    this.busqueda = '',
    this.tipo,
    this.soloEntradas,
    this.desde,
    this.hasta,
    this.productoId,
    this.usuarioId,
  });

  final List<MovimientoDetalle> items;
  final int total;
  final int pagina;
  final int tamanoPagina;

  final String busqueda;
  final TipoMovimiento? tipo;
  final bool? soloEntradas;
  final DateTime? desde;
  final DateTime? hasta;
  final int? productoId;

  /// Quién movió el stock. Ya estaba resuelto en SQL y con su índice; lo que
  /// faltaba era el desplegable que lo eligiera.
  final int? usuarioId;

  int get totalPaginas =>
      total <= 0 ? 1 : (total + tamanoPagina - 1) ~/ tamanoPagina;

  bool get hayFiltro => filtro.hayFiltro;

  FiltroMovimientos get filtro => FiltroMovimientos(
        productoId: productoId,
        tipo: tipo,
        soloEntradas: soloEntradas,
        desde: desde,
        hasta: hasta,
        busqueda: busqueda,
        usuarioId: usuarioId,
      );

  /// Los campos que se pueden **quitar** llevan un `bool` aparte: con solo el
  /// valor nulo no habría forma de distinguir «no lo cambies» de «bórralo».
  MovimientosState copyWith({
    List<MovimientoDetalle>? items,
    int? total,
    int? pagina,
    String? busqueda,
    TipoMovimiento? tipo,
    bool limpiarTipo = false,
    bool? soloEntradas,
    bool limpiarSentido = false,
    DateTime? desde,
    bool limpiarDesde = false,
    DateTime? hasta,
    bool limpiarHasta = false,
    int? productoId,
    bool limpiarProducto = false,
    int? usuarioId,
    bool limpiarUsuario = false,
  }) =>
      MovimientosState(
        items: items ?? this.items,
        total: total ?? this.total,
        pagina: pagina ?? this.pagina,
        tamanoPagina: tamanoPagina,
        busqueda: busqueda ?? this.busqueda,
        tipo: limpiarTipo ? null : (tipo ?? this.tipo),
        soloEntradas:
            limpiarSentido ? null : (soloEntradas ?? this.soloEntradas),
        desde: limpiarDesde ? null : (desde ?? this.desde),
        hasta: limpiarHasta ? null : (hasta ?? this.hasta),
        productoId: limpiarProducto ? null : (productoId ?? this.productoId),
        usuarioId: limpiarUsuario ? null : (usuarioId ?? this.usuarioId),
      );
}

class MovimientosNotifier extends AsyncNotifier<MovimientosState> {
  /// `late` **sin `final`**: Riverpod conserva la instancia del notifier y
  /// vuelve a llamar a `build()` cuando el provider se invalida.
  late RepositorioInventario _repo;
  StreamSubscription<PaginaMovimientos>? _sub;

  @override
  Future<MovimientosState> build() async {
    _repo = ref.watch(repositorioInventarioProvider);
    ref.onDispose(() => _sub?.cancel());

    const inicial = MovimientosState();
    final primera = await _repo
        .observarPagina(
          filtro: inicial.filtro,
          pagina: inicial.pagina,
          tamano: inicial.tamanoPagina,
        )
        .first;

    _suscribir(inicial);
    return inicial.copyWith(items: primera.items, total: primera.total);
  }

  /// Reabre el stream con los filtros y la página vigentes. Cada cambio de
  /// filtro es una consulta nueva, no un recorte en memoria.
  void _suscribir(MovimientosState estado) {
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
          actual.copyWith(items: pagina.items, total: pagina.total),
        );
      },
      onError: (Object e, StackTrace st) => state = AsyncError(e, st),
    );
  }

  void _aplicar(MovimientosState nuevo) {
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
  void filtrarPorTipo(TipoMovimiento? tipo) {
    final actual = state.value;
    if (actual == null) return;
    final quitar = tipo == null || actual.tipo == tipo;
    _aplicar(actual.copyWith(
      tipo: quitar ? null : tipo,
      limpiarTipo: quitar,
      pagina: 0,
    ));
  }

  /// Quién movió el stock. `null` vuelve a «cualquiera».
  void filtrarPorUsuario(int? usuarioId) {
    final actual = state.value;
    if (actual == null || actual.usuarioId == usuarioId) return;
    _aplicar(actual.copyWith(
      usuarioId: usuarioId,
      limpiarUsuario: usuarioId == null,
      pagina: 0,
    ));
  }

  void filtrarPorSentido(bool? soloEntradas) {
    final actual = state.value;
    if (actual == null) return;
    final quitar = soloEntradas == null || actual.soloEntradas == soloEntradas;
    _aplicar(actual.copyWith(
      soloEntradas: quitar ? null : soloEntradas,
      limpiarSentido: quitar,
      pagina: 0,
    ));
  }

  /// El rango es inclusivo, así que [hasta] se estira al final del día: con la
  /// medianoche, pedir «hasta hoy» dejaría fuera lo que se movió hoy.
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
    _aplicar(const MovimientosState());
  }

  void irAPagina(int pagina) {
    final actual = state.value;
    if (actual == null || pagina == actual.pagina) return;
    if (pagina < 0 || pagina >= actual.totalPaginas) return;
    _aplicar(actual.copyWith(pagina: pagina));
  }
}

final movimientosProvider =
    AsyncNotifierProvider<MovimientosNotifier, MovimientosState>(
  MovimientosNotifier.new,
  name: 'movimientosProvider',
);

/// Los movimientos de la página actual.
final movimientosPaginaProvider = Provider<List<MovimientoDetalle>>(
  name: 'movimientosPaginaProvider',
  (ref) => ref.watch(movimientosProvider).value?.items ?? const [],
);
