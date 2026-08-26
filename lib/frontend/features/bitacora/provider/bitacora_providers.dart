import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/bitacora/modelo/entrada_bitacora.dart';
import '../../../../backend/features/bitacora/repositorio/repositorio_bitacora.dart';
import '../../../../backend/features/bitacora/repositorio/repositorio_bitacora_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../autenticacion/provider/auth_providers.dart';

/// Providers de la bitácora.
///
/// El `WHERE`, el `COUNT` y el `LIMIT` los resuelve SQLite: la bitácora es la
/// tabla que más crece del proyecto —un renglón por cada edición y cada
/// borrado— y es la última que puede permitirse traerse entera para filtrar en
/// memoria (`REGLAS_BD.md` §5).

final repositorioBitacoraProvider = Provider<RepositorioBitacora>(
  name: 'repositorioBitacoraProvider',
  (ref) => RepositorioBitacoraImpl(
    ref.watch(appDatabaseProvider),
    // La sesión va por el constructor: es quien firma cada renglón, y también
    // contra quien se comprueba el permiso de lectura (`CLAUDE.md` §3).
    ref.watch(sesionActualProvider),
  ),
);

/// Estado del listado: **solo la página visible**, más lo que hace falta para
/// pintar el paginador y saber qué filtros están puestos.
final class BitacoraListaState {
  const BitacoraListaState({
    this.items = const [],
    this.total = 0,
    this.pagina = 0,
    this.tamanoPagina = 15,
    this.busqueda = '',
    this.usuarioId,
    this.entidad,
    this.accion,
    this.desde,
    this.hasta,
  });

  final List<EntradaBitacora> items;

  /// Renglones que cumplen el filtro en total, no solo en esta página.
  final int total;

  final int pagina;
  final int tamanoPagina;

  final String busqueda;
  final int? usuarioId;
  final EntidadAuditada? entidad;
  final AccionAuditada? accion;
  final DateTime? desde;
  final DateTime? hasta;

  int get totalPaginas =>
      total <= 0 ? 1 : (total + tamanoPagina - 1) ~/ tamanoPagina;

  bool get hayFiltro => filtro.hayFiltro;

  FiltroBitacora get filtro => FiltroBitacora(
        usuarioId: usuarioId,
        entidad: entidad,
        accion: accion,
        desde: desde,
        hasta: hasta,
        busqueda: busqueda,
      );

  /// Los campos que se pueden **quitar** llevan un `bool` aparte: con solo el
  /// valor nulo no habría forma de distinguir «no lo cambies» de «bórralo».
  BitacoraListaState copyWith({
    List<EntradaBitacora>? items,
    int? total,
    int? pagina,
    String? busqueda,
    int? usuarioId,
    bool limpiarUsuario = false,
    EntidadAuditada? entidad,
    bool limpiarEntidad = false,
    AccionAuditada? accion,
    bool limpiarAccion = false,
    DateTime? desde,
    bool limpiarDesde = false,
    DateTime? hasta,
    bool limpiarHasta = false,
  }) =>
      BitacoraListaState(
        items: items ?? this.items,
        total: total ?? this.total,
        pagina: pagina ?? this.pagina,
        tamanoPagina: tamanoPagina,
        busqueda: busqueda ?? this.busqueda,
        usuarioId: limpiarUsuario ? null : (usuarioId ?? this.usuarioId),
        entidad: limpiarEntidad ? null : (entidad ?? this.entidad),
        accion: limpiarAccion ? null : (accion ?? this.accion),
        desde: limpiarDesde ? null : (desde ?? this.desde),
        hasta: limpiarHasta ? null : (hasta ?? this.hasta),
      );
}

class BitacoraListaNotifier extends AsyncNotifier<BitacoraListaState> {
  /// `late` **sin `final`**: Riverpod conserva la instancia del notifier y
  /// vuelve a llamar a `build()` cuando el provider se invalida. Con
  /// `late final`, esa segunda pasada revienta.
  late RepositorioBitacora _repo;
  StreamSubscription<PaginaBitacora>? _sub;

  @override
  Future<BitacoraListaState> build() async {
    _repo = ref.watch(repositorioBitacoraProvider);
    ref.onDispose(() => _sub?.cancel());

    const inicial = BitacoraListaState();
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
  void _suscribir(BitacoraListaState estado) {
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

  void _aplicar(BitacoraListaState nuevo) {
    state = AsyncData(nuevo);
    _suscribir(nuevo);
  }

  // Todo filtro vuelve a la primera página: el conjunto cambió y la página
  // siete del anterior no significa nada en el nuevo.

  void buscar(String texto) {
    final actual = state.value;
    if (actual == null) return;
    final limpio = texto.trim();
    if (actual.busqueda == limpio) return;
    _aplicar(actual.copyWith(busqueda: limpio, pagina: 0));
  }

  /// Tocar el valor ya activo lo quita: el mismo gesto pone y saca, sin
  /// necesitar un botón por filtro.
  void filtrarPorUsuario(int? usuarioId) {
    final actual = state.value;
    if (actual == null) return;
    final quitar = usuarioId == null || actual.usuarioId == usuarioId;
    _aplicar(actual.copyWith(
      usuarioId: quitar ? null : usuarioId,
      limpiarUsuario: quitar,
      pagina: 0,
    ));
  }

  void filtrarPorEntidad(EntidadAuditada? entidad) {
    final actual = state.value;
    if (actual == null) return;
    final quitar = entidad == null || actual.entidad == entidad;
    _aplicar(actual.copyWith(
      entidad: quitar ? null : entidad,
      limpiarEntidad: quitar,
      pagina: 0,
    ));
  }

  void filtrarPorAccion(AccionAuditada? accion) {
    final actual = state.value;
    if (actual == null) return;
    final quitar = accion == null || actual.accion == accion;
    _aplicar(actual.copyWith(
      accion: quitar ? null : accion,
      limpiarAccion: quitar,
      pagina: 0,
    ));
  }

  /// El rango es inclusivo por los dos lados, así que [hasta] se estira al
  /// final del día elegido: con la medianoche, pedir «hasta hoy» dejaría fuera
  /// todo lo que pasó hoy, que es justo lo que se está mirando.
  void filtrarPorFechas({DateTime? desde, DateTime? hasta}) {
    final actual = state.value;
    if (actual == null) return;
    _aplicar(actual.copyWith(
      desde: desde == null ? null : DateTime(desde.year, desde.month, desde.day),
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
    _aplicar(const BitacoraListaState());
  }

  void irAPagina(int pagina) {
    final actual = state.value;
    if (actual == null || pagina == actual.pagina) return;
    if (pagina < 0 || pagina >= actual.totalPaginas) return;
    _aplicar(actual.copyWith(pagina: pagina));
  }
}

final bitacoraListaProvider =
    AsyncNotifierProvider<BitacoraListaNotifier, BitacoraListaState>(
  BitacoraListaNotifier.new,
  name: 'bitacoraListaProvider',
);

/// Los renglones de la página actual.
final bitacoraPaginaProvider = Provider<List<EntradaBitacora>>(
  name: 'bitacoraPaginaProvider',
  (ref) => ref.watch(bitacoraListaProvider).value?.items ?? const [],
);
