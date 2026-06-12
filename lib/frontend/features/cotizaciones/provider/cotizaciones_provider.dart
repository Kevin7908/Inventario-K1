import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:inventario_k1/backend/features/clientes/repositorio/repositorio_cliente_impl.dart';
import 'package:inventario_k1/backend/features/motos/repositorio/repositorio_moto_impl.dart';
import 'package:inventario_k1/backend/features/motos/modelo/moto.dart';
import 'package:inventario_k1/backend/features/clientes/modelo/cliente.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/features/productos/repositorio/repositorio_producto_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db_provider.dart';

import '../../../../backend/features/cotizaciones/enum/enum_cotizacion.dart';
import '../../../../backend/features/cotizaciones/modelo/cotizacion_detalle.dart';
import '../../../../backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import '../../../../backend/features/cotizaciones/repositorio/repositorio_cotizaciones.dart';
import '../../../../backend/features/cotizaciones/repositorio/repositorio_cotizaciones_impl.dart';

// ── Repositorio ──────────────────────────────────────────────────────────────

final repositorioCotizacionesProvider = Provider<RepositorioCotizaciones>(
  name: 'repositorioCotizacionesProvider',
  (ref) => RepositorioCotizacionesImpl(ref.watch(appDatabaseProvider)),
);

// ── Estado ────────────────────────────────────────────────────────────────────

final class CotizacionesState {
  const CotizacionesState({
    this.cotizaciones = const [],
    this.filtroBusqueda = '',
    this.filtroEstado,
    this.filtroMes,
    this.paginaActual = 0,
  });

  final List<CotizacionResumen> cotizaciones;
  final String filtroBusqueda;
  final EstadoCotizacion? filtroEstado;
  final int? filtroMes;
  final int paginaActual;

  static const int itemsPorPagina = 10;

  CotizacionesState copyWith({
    List<CotizacionResumen>? cotizaciones,
    String? filtroBusqueda,
    Object? filtroEstado = _sentinel,
    Object? filtroMes = _sentinel,
    int? paginaActual,
  }) {
    return CotizacionesState(
      cotizaciones: cotizaciones ?? this.cotizaciones,
      filtroBusqueda: filtroBusqueda ?? this.filtroBusqueda,
      filtroEstado: filtroEstado == _sentinel
          ? this.filtroEstado
          : filtroEstado as EstadoCotizacion?,
      filtroMes:
          filtroMes == _sentinel ? this.filtroMes : filtroMes as int?,
      paginaActual: paginaActual ?? this.paginaActual,
    );
  }

  static const Object _sentinel = Object();

}

// ── Notifier ──────────────────────────────────────────────────────────────────

class CotizacionesNotifier extends AsyncNotifier<CotizacionesState> {
  late final RepositorioCotizaciones _repo;

  @override
  Future<CotizacionesState> build() async {
    _repo = ref.watch(repositorioCotizacionesProvider);

    final sub = _repo.observarTodas().listen(
      (lista) {
        final actual = state.value;
        state = AsyncData(
          actual != null
              ? actual.copyWith(cotizaciones: lista)
              : CotizacionesState(cotizaciones: lista),
        );
      },
      onError: (Object e, StackTrace st) => state = AsyncError(e, st),
    );
    ref.onDispose(sub.cancel);

    final lista = await _repo.obtenerTodas();
    return CotizacionesState(cotizaciones: lista);
  }

  // ── Filtros ──────────────────────────────────────────────────────────────────

  void buscar(String q) {
    final actual = state.value;
    if (actual == null) return;
    state = AsyncData(actual.copyWith(filtroBusqueda: q.trim(), paginaActual: 0));
  }

  void filtrarEstado(EstadoCotizacion? e) {
    final actual = state.value;
    if (actual == null) return;
    state = AsyncData(actual.copyWith(filtroEstado: e, paginaActual: 0));
  }

  void filtrarMes(int? mes) {
    final actual = state.value;
    if (actual == null) return;
    state = AsyncData(actual.copyWith(filtroMes: mes, paginaActual: 0));
  }

  void cambiarPagina(int pagina) {
    final actual = state.value;
    if (actual == null) return;
    state = AsyncData(actual.copyWith(paginaActual: pagina));
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────────

  Future<String?> crear({
    int? clienteId,
    int? motoId,
    required String vigenciaHasta,
    String? notas,
    required List<ItemDraft> items,
  }) async {
    try {
      await _repo.crear(
        clienteId: clienteId,
        motoId: motoId,
        vigenciaHasta: vigenciaHasta,
        notas: notas,
        items: items,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> actualizar({
    required int id,
    int? clienteId,
    int? motoId,
    required String vigenciaHasta,
    String? notas,
    required List<ItemDraft> items,
  }) async {
    try {
      await _repo.actualizar(
        id: id,
        clienteId: clienteId,
        motoId: motoId,
        vigenciaHasta: vigenciaHasta,
        notas: notas,
        items: items,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> eliminar(int id) async {
    final actual = state.value;
    if (actual == null) return null;

    final snapshot = actual.cotizaciones;
    state = AsyncData(actual.copyWith(
      cotizaciones: snapshot.where((c) => c.id != id).toList(growable: false),
    ));
    try {
      await _repo.eliminar(id);
      return null;
    } catch (e) {
      state = AsyncData(actual.copyWith(cotizaciones: snapshot));
      return e.toString();
    }
  }

  // ── CRUD Items (desde panel lateral) ─────────────────────────────────────────

  Future<String?> agregarItem({
    required int cotizacionId,
    required TipoItemCotizacion tipo,
    int? referenciaId,
    required String descripcion,
    required double cantidad,
    required int precioUnitario,
  }) async {
    try {
      await _repo.agregarItem(
        cotizacionId: cotizacionId,
        tipo: tipo,
        referenciaId: referenciaId,
        descripcion: descripcion,
        cantidad: cantidad,
        precioUnitario: precioUnitario,
      );
      ref.invalidate(cotizacionDetalleProvider(cotizacionId));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> eliminarItem(int itemId, int cotizacionId) async {
    try {
      await _repo.eliminarItem(itemId, cotizacionId);
      ref.invalidate(cotizacionDetalleProvider(cotizacionId));
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

// ── Providers públicos ────────────────────────────────────────────────────────

/// ID de la cotización seleccionada en el panel lateral.
/// autoDispose garantiza que se reinicia al salir de la vista.
final cotSeleccionadaIdProvider = StateProvider.autoDispose<int?>(
  (ref) => null,
  name: 'cotSeleccionadaIdProvider',
);

final cotizacionesProvider =
    AsyncNotifierProvider<CotizacionesNotifier, CotizacionesState>(
  CotizacionesNotifier.new,
  name: 'cotizacionesProvider',
);

final cotizacionDetalleProvider =
    FutureProvider.family<CotizacionDetalle, int>(
  name: 'cotizacionDetalleProvider',
  (ref, id) => ref.watch(repositorioCotizacionesProvider).obtenerDetalle(id),
);

// ── Providers de datos de apoyo (para el diálogo) ────────────────────────────

final motosParaCotizacionProvider = FutureProvider<List<Moto>>(
  name: 'motosParaCotizacionProvider',
  (ref) => RepositorioMotosImpl(ref.watch(appDatabaseProvider)).obtenerTodos(),
);

final clientesParaCotizacionProvider = FutureProvider<List<Cliente>>(
  name: 'clientesParaCotizacionProvider',
  (ref) =>
      RepositorioClientesImpl(ref.watch(appDatabaseProvider)).obtenerTodos(),
);

final productosParaCotizacionProvider = FutureProvider<List<Producto>>(
  name: 'productosParaCotizacionProvider',
  (ref) =>
      RepositorioProductosImpl(ref.watch(appDatabaseProvider)).obtenerActivos(),
);

// ── Modelos de valor para providers derivados ─────────────────────────────────

final class CotizacionesMetrics {
  const CotizacionesMetrics({
    required this.total,
    required this.valorTotal,
    required this.cantVigentes,
    required this.cantVencidas,
    required this.cantPorVencer,
  });

  final int total;
  final int valorTotal;
  final int cantVigentes;
  final int cantVencidas;
  final int cantPorVencer;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CotizacionesMetrics &&
          total == other.total &&
          valorTotal == other.valorTotal &&
          cantVigentes == other.cantVigentes &&
          cantVencidas == other.cantVencidas &&
          cantPorVencer == other.cantPorVencer;

  @override
  int get hashCode =>
      Object.hash(total, valorTotal, cantVigentes, cantVencidas, cantPorVencer);
}

final class PaginacionCotizaciones {
  const PaginacionCotizaciones({
    required this.paginadas,
    required this.paginaActual,
    required this.totalPaginas,
    required this.totalFiltradas,
  });

  final List<CotizacionResumen> paginadas;
  final int paginaActual;
  final int totalPaginas;
  final int totalFiltradas;
}

// ── Providers derivados ───────────────────────────────────────────────────────

/// Solo recalcula cuando cambia la lista base, sin importar filtros ni página.
final cotizacionesMetricsProvider = Provider<CotizacionesMetrics>(
  name: 'cotizacionesMetricsProvider',
  (ref) {
    final lista = ref.watch(
      cotizacionesProvider.select(
        (s) => s.asData?.value.cotizaciones ?? const [],
      ),
    );
    return CotizacionesMetrics(
      total: lista.length,
      valorTotal: lista.fold(0, (acc, c) => acc + c.total),
      cantVigentes:
          lista.where((c) => c.estado == EstadoCotizacion.vigente).length,
      cantVencidas:
          lista.where((c) => c.estado == EstadoCotizacion.vencida).length,
      cantPorVencer:
          lista.where((c) => c.estado == EstadoCotizacion.porVencer).length,
    );
  },
);

/// Solo recalcula cuando cambia la lista base o alguno de los tres filtros.
/// Cambiar solo la página NO dispara este provider.
final cotizacionesFiltradasProvider = Provider<List<CotizacionResumen>>(
  name: 'cotizacionesFiltradasProvider',
  (ref) {
    // Dart records tienen igualdad estructural → .select compara campo a campo.
    final p = ref.watch(cotizacionesProvider.select((s) {
      final v = s.asData?.value;
      if (v == null) {
        return (
          lista: <CotizacionResumen>[],
          estado: null as EstadoCotizacion?,
          mes: null as int?,
          busqueda: '',
        );
      }
      return (
        lista: v.cotizaciones,
        estado: v.filtroEstado,
        mes: v.filtroMes,
        busqueda: v.filtroBusqueda,
      );
    }));

    var lista = p.lista;
    if (p.estado != null) {
      lista = lista.where((c) => c.estado == p.estado).toList();
    }
    if (p.mes != null) {
      lista = lista.where((c) => c.creadoEn.month == p.mes).toList();
    }
    final q = p.busqueda.toLowerCase();
    if (q.isNotEmpty) {
      lista = lista
          .where(
            (c) =>
                c.numero.toLowerCase().contains(q) ||
                c.nombreCliente.toLowerCase().contains(q) ||
                c.nombreMoto.toLowerCase().contains(q),
          )
          .toList();
    }
    return lista;
  },
);

/// Recalcula cuando cambia la lista filtrada O el número de página activa.
final paginacionProvider = Provider<PaginacionCotizaciones>(
  name: 'paginacionProvider',
  (ref) {
    final filtradas = ref.watch(cotizacionesFiltradasProvider);
    final paginaActual = ref.watch(
      cotizacionesProvider.select((s) => s.asData?.value.paginaActual ?? 0),
    );

    const items = CotizacionesState.itemsPorPagina;
    final total = filtradas.length;
    final totalPaginas = (total / items).ceil().clamp(1, 9999);
    final inicio = paginaActual * items;
    final fin = (inicio + items).clamp(0, total);
    final paginadas =
        inicio >= total ? const <CotizacionResumen>[] : filtradas.sublist(inicio, fin);

    return PaginacionCotizaciones(
      paginadas: paginadas,
      paginaActual: paginaActual,
      totalPaginas: totalPaginas,
      totalFiltradas: total,
    );
  },
);

