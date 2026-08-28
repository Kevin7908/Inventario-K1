import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/pos/enum/enum_ventas.dart';
import '../../../../backend/features/pos/modelo/venta_resumen.dart';
import '../../../../backend/features/pos/repositorio/repositorio_ventas.dart';
import '../../pos/provider/pos_providers.dart';

/// Providers del historial de ventas.
///
/// El repositorio es el mismo del punto de venta: el POS escribe las facturas
/// y esta pantalla las lee. No hay dos fuentes.

/// Estado del listado: **solo la página visible**, más lo que hace falta para
/// pintar el paginador y saber qué filtros están puestos.
final class HistorialVentasState {
  const HistorialVentasState({
    this.items = const [],
    this.total = 0,
    this.pagina = 0,
    this.tamanoPagina = 15,
    this.busqueda = '',
    this.tipo,
    this.estado,
    this.desde,
    this.hasta,
  });

  final List<VentaResumen> items;
  final int total;
  final int pagina;
  final int tamanoPagina;

  final String busqueda;
  final TipoVenta? tipo;
  final EstadoPago? estado;
  final DateTime? desde;
  final DateTime? hasta;

  int get totalPaginas =>
      total <= 0 ? 1 : (total + tamanoPagina - 1) ~/ tamanoPagina;

  bool get hayFiltro => filtro.hayFiltro;

  FiltroVentas get filtro => FiltroVentas(
        tipo: tipo,
        estado: estado,
        desde: desde,
        hasta: hasta,
        busqueda: busqueda,
      );

  /// Los campos que se pueden **quitar** llevan un `bool` aparte: con solo el
  /// valor nulo no habría forma de distinguir «no lo cambies» de «bórralo».
  HistorialVentasState copyWith({
    List<VentaResumen>? items,
    int? total,
    int? pagina,
    String? busqueda,
    TipoVenta? tipo,
    bool limpiarTipo = false,
    EstadoPago? estado,
    bool limpiarEstado = false,
    DateTime? desde,
    bool limpiarDesde = false,
    DateTime? hasta,
    bool limpiarHasta = false,
  }) =>
      HistorialVentasState(
        items: items ?? this.items,
        total: total ?? this.total,
        pagina: pagina ?? this.pagina,
        tamanoPagina: tamanoPagina,
        busqueda: busqueda ?? this.busqueda,
        tipo: limpiarTipo ? null : (tipo ?? this.tipo),
        estado: limpiarEstado ? null : (estado ?? this.estado),
        desde: limpiarDesde ? null : (desde ?? this.desde),
        hasta: limpiarHasta ? null : (hasta ?? this.hasta),
      );
}

class HistorialVentasNotifier extends AsyncNotifier<HistorialVentasState> {
  /// `late` **sin `final`**: Riverpod conserva la instancia del notifier y
  /// vuelve a llamar a `build()` cuando el provider se invalida.
  late RepositorioVentas _repo;
  StreamSubscription<PaginaVentas>? _sub;

  @override
  Future<HistorialVentasState> build() async {
    _repo = ref.watch(repositorioVentasProvider);
    ref.onDispose(() => _sub?.cancel());

    const inicial = HistorialVentasState();
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
  void _suscribir(HistorialVentasState estado) {
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

  void _aplicar(HistorialVentasState nuevo) {
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
  void filtrarPorTipo(TipoVenta? tipo) {
    final actual = state.value;
    if (actual == null) return;
    final quitar = tipo == null || actual.tipo == tipo;
    _aplicar(actual.copyWith(
      tipo: quitar ? null : tipo,
      limpiarTipo: quitar,
      pagina: 0,
    ));
  }

  void filtrarPorEstado(EstadoPago? estado) {
    final actual = state.value;
    if (actual == null) return;
    final quitar = estado == null || actual.estado == estado;
    _aplicar(actual.copyWith(
      estado: quitar ? null : estado,
      limpiarEstado: quitar,
      pagina: 0,
    ));
  }

  /// El rango es inclusivo, así que [hasta] se estira al final del día: con la
  /// medianoche, pedir «hasta hoy» dejaría fuera lo que se vendió hoy.
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
    _aplicar(const HistorialVentasState());
  }

  void irAPagina(int pagina) {
    final actual = state.value;
    if (actual == null || pagina == actual.pagina) return;
    if (pagina < 0 || pagina >= actual.totalPaginas) return;
    _aplicar(actual.copyWith(pagina: pagina));
  }
}

final historialVentasProvider =
    AsyncNotifierProvider<HistorialVentasNotifier, HistorialVentasState>(
  HistorialVentasNotifier.new,
  name: 'historialVentasProvider',
);

/// Las ventas de la página actual.
final ventasPaginaProvider = Provider<List<VentaResumen>>(
  name: 'ventasPaginaProvider',
  (ref) => ref.watch(historialVentasProvider).value?.items ?? const [],
);
