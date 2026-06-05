import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/backend/features/motos/repositorio/repositorio_moto_impl.dart';
import 'package:inventario_k1/backend/features/motos/modelo/moto.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/features/productos/repositorio/repositorio_producto_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db_provider.dart';

import '../../../../backend/features/reservas/enum/enum_reserva.dart';
import '../../../../backend/features/reservas/modelo/reserva_detalle.dart';
import '../../../../backend/features/reservas/modelo/reserva_resumen.dart';
import '../../../../backend/features/reservas/repositorio/repositorio_reservas.dart';
import '../../../../backend/features/reservas/repositorio/repositorio_reservas_impl.dart';

// ── Repositorio ───────────────────────────────────────────────────────────────

final repositorioReservasProvider = Provider<RepositorioReservas>(
  name: 'repositorioReservasProvider',
  (ref) => RepositorioReservasImpl(ref.watch(appDatabaseProvider)),
);

// ── Enums de modo del panel ───────────────────────────────────────────────────

enum ModoPanel { vacio, detalle, formulario }

// ── Estado ────────────────────────────────────────────────────────────────────

final class ReservasState {
  const ReservasState({
    this.reservas = const [],
    this.filtroBusqueda = '',
    this.filtroEstado,
    this.paginaActual = 0,
    this.reservaSeleccionadaId,
    this.modoPanel = ModoPanel.vacio,
    this.mostrarFormAbono = false,
  });

  final List<ReservaResumen> reservas;
  final String filtroBusqueda;
  final EstadoReserva? filtroEstado;
  final int paginaActual;
  final int? reservaSeleccionadaId;
  final ModoPanel modoPanel;
  final bool mostrarFormAbono;

  static const int itemsPorPagina = 12;

  ReservasState copyWith({
    List<ReservaResumen>? reservas,
    String? filtroBusqueda,
    Object? filtroEstado = _sentinel,
    int? paginaActual,
    Object? reservaSeleccionadaId = _sentinel,
    ModoPanel? modoPanel,
    bool? mostrarFormAbono,
  }) {
    return ReservasState(
      reservas: reservas ?? this.reservas,
      filtroBusqueda: filtroBusqueda ?? this.filtroBusqueda,
      filtroEstado: filtroEstado == _sentinel
          ? this.filtroEstado
          : filtroEstado as EstadoReserva?,
      paginaActual: paginaActual ?? this.paginaActual,
      reservaSeleccionadaId: reservaSeleccionadaId == _sentinel
          ? this.reservaSeleccionadaId
          : reservaSeleccionadaId as int?,
      modoPanel: modoPanel ?? this.modoPanel,
      mostrarFormAbono: mostrarFormAbono ?? this.mostrarFormAbono,
    );
  }

  static const Object _sentinel = Object();
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ReservasNotifier extends AsyncNotifier<ReservasState> {
  late final RepositorioReservas _repo;

  @override
  Future<ReservasState> build() async {
    _repo = ref.watch(repositorioReservasProvider);

    final sub = _repo.observarTodas().listen(
      (lista) {
        final actual = state.value;
        state = AsyncData(
          actual != null
              ? actual.copyWith(reservas: lista)
              : ReservasState(reservas: lista),
        );
      },
      onError: (Object e, StackTrace st) => state = AsyncError(e, st),
    );
    ref.onDispose(sub.cancel);

    final lista = await _repo.obtenerTodas();
    return ReservasState(reservas: lista);
  }

  // ── Filtros y navegación ──────────────────────────────────────────────────

  void buscar(String q) {
    _mutate((s) => s.copyWith(filtroBusqueda: q.trim(), paginaActual: 0));
  }

  void filtrarEstado(EstadoReserva? estado) {
    _mutate((s) => s.copyWith(filtroEstado: estado, paginaActual: 0));
  }

  void cambiarPagina(int pagina) {
    _mutate((s) => s.copyWith(paginaActual: pagina));
  }

  // ── Panel derecho ─────────────────────────────────────────────────────────

  void abrirDetalle(int reservaId) {
    _mutate((s) => s.copyWith(
          reservaSeleccionadaId: reservaId,
          modoPanel: ModoPanel.detalle,
          mostrarFormAbono: false,
        ));
  }

  void abrirNueva() {
    _mutate((s) => s.copyWith(
          reservaSeleccionadaId: null,
          modoPanel: ModoPanel.formulario,
          mostrarFormAbono: false,
        ));
  }

  void abrirEditar(int reservaId) {
    _mutate((s) => s.copyWith(
          reservaSeleccionadaId: reservaId,
          modoPanel: ModoPanel.formulario,
          mostrarFormAbono: false,
        ));
  }

  void cerrarPanel() {
    _mutate((s) => s.copyWith(
          reservaSeleccionadaId: null,
          modoPanel: ModoPanel.vacio,
          mostrarFormAbono: false,
        ));
  }

  void toggleFormAbono() {
    _mutate((s) => s.copyWith(mostrarFormAbono: !s.mostrarFormAbono));
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<String?> crear({
    required int clienteId,
    int? motoId,
    int? cotizacionId,
    required String fechaLimite,
    required int totalReserva,
    required List<ItemReservaDraft> items,
    int abonoInicial = 0,
    String metodoPagoInicial = 'Efectivo',
    String? referenciaInicial,
  }) async {
    try {
      final id = await _repo.crear(
        clienteId: clienteId,
        motoId: motoId,
        cotizacionId: cotizacionId,
        fechaLimite: fechaLimite,
        totalReserva: totalReserva,
        items: items,
        abonoInicial: abonoInicial,
        metodoPagoInicial: metodoPagoInicial,
        referenciaInicial: referenciaInicial,
      );
      _mutate((s) => s.copyWith(
            reservaSeleccionadaId: id,
            modoPanel: ModoPanel.detalle,
          ));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> actualizar({
    required int id,
    int? motoId,
    int? cotizacionId,
    required String fechaLimite,
    required int totalReserva,
    required List<ItemReservaDraft> items,
  }) async {
    try {
      await _repo.actualizar(
        id: id,
        motoId: motoId,
        cotizacionId: cotizacionId,
        fechaLimite: fechaLimite,
        totalReserva: totalReserva,
        items: items,
      );
      _mutate((s) => s.copyWith(
            reservaSeleccionadaId: id,
            modoPanel: ModoPanel.detalle,
          ));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> registrarAbono({
    required int reservaId,
    required int monto,
    required String metodoPago,
    String? referenciaPago,
  }) async {
    try {
      await _repo.registrarAbono(
        reservaId: reservaId,
        monto: monto,
        metodoPago: metodoPago,
        referenciaPago: referenciaPago,
      );
      _mutate((s) => s.copyWith(mostrarFormAbono: false));
      ref.invalidate(reservaDetalleProvider(reservaId));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> cambiarEstado(int id, EstadoReserva nuevoEstado) async {
    try {
      await _repo.cambiarEstado(id, nuevoEstado);
      ref.invalidate(reservaDetalleProvider(id));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> eliminar(int id) async {
    final actual = state.value;
    if (actual == null) return null;

    final snapshot = actual.reservas;
    _mutate((s) => s.copyWith(
          reservas: snapshot.where((r) => r.id != id).toList(growable: false),
          reservaSeleccionadaId: null,
          modoPanel: ModoPanel.vacio,
        ));
    try {
      await _repo.eliminar(id);
      return null;
    } catch (e) {
      _mutate((s) => s.copyWith(reservas: snapshot));
      return e.toString();
    }
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  void _mutate(ReservasState Function(ReservasState) fn) {
    final actual = state.value;
    if (actual == null) return;
    state = AsyncData(fn(actual));
  }
}

// ── Providers públicos ────────────────────────────────────────────────────────

final reservasProvider =
    AsyncNotifierProvider<ReservasNotifier, ReservasState>(
  ReservasNotifier.new,
  name: 'reservasProvider',
);

final reservaDetalleProvider = FutureProvider.autoDispose.family<ReservaDetalle, int>(
  name: 'reservaDetalleProvider',
  (ref, id) => ref.watch(repositorioReservasProvider).obtenerDetalle(id),
);

// ── Providers de datos de apoyo ───────────────────────────────────────────────

final motosParaReservaProvider = FutureProvider<List<Moto>>(
  name: 'motosParaReservaProvider',
  (ref) => RepositorioMotosImpl(ref.watch(appDatabaseProvider)).obtenerTodos(),
);

final productosParaReservaProvider = FutureProvider<List<Producto>>(
  name: 'productosParaReservaProvider',
  (ref) =>
      RepositorioProductosImpl(ref.watch(appDatabaseProvider)).obtenerTodos(),
);

// ── Modelos derivados ─────────────────────────────────────────────────────────

final class ReservasMetrics {
  const ReservasMetrics({
    required this.cantActivas,
    required this.cantCompletadas,
    required this.cantVencidas,
    required this.porCobrar,
  });

  final int cantActivas;
  final int cantCompletadas;
  final int cantVencidas;
  final int porCobrar;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReservasMetrics &&
          cantActivas == other.cantActivas &&
          cantCompletadas == other.cantCompletadas &&
          cantVencidas == other.cantVencidas &&
          porCobrar == other.porCobrar;

  @override
  int get hashCode =>
      Object.hash(cantActivas, cantCompletadas, cantVencidas, porCobrar);
}

final class PaginacionReservas {
  const PaginacionReservas({
    required this.paginadas,
    required this.paginaActual,
    required this.totalPaginas,
    required this.totalFiltradas,
  });

  final List<ReservaResumen> paginadas;
  final int paginaActual;
  final int totalPaginas;
  final int totalFiltradas;
}

// ── Providers derivados ───────────────────────────────────────────────────────

final reservasMetricsProvider = Provider<ReservasMetrics>(
  name: 'reservasMetricsProvider',
  (ref) {
    final lista = ref.watch(
      reservasProvider.select((s) => s.asData?.value.reservas ?? const []),
    );
    final activas = lista.where((r) => r.estado == EstadoReserva.activa).toList();
    return ReservasMetrics(
      cantActivas: activas.length,
      cantCompletadas:
          lista.where((r) => r.estado == EstadoReserva.completada).length,
      cantVencidas: activas.where((r) => r.estaVencida).length,
      porCobrar: activas.fold(0, (s, r) => s + r.saldo),
    );
  },
);

final reservasFiltradasProvider = Provider<List<ReservaResumen>>(
  name: 'reservasFiltradasProvider',
  (ref) {
    final p = ref.watch(reservasProvider.select((s) {
      final v = s.asData?.value;
      if (v == null) {
        return (
          lista: <ReservaResumen>[],
          estado: null as EstadoReserva?,
          busqueda: '',
        );
      }
      return (lista: v.reservas, estado: v.filtroEstado, busqueda: v.filtroBusqueda);
    }));

    var lista = p.lista;
    if (p.estado != null) {
      lista = lista.where((r) => r.estado == p.estado).toList();
    }
    final q = p.busqueda.toLowerCase();
    if (q.isNotEmpty) {
      lista = lista
          .where((r) =>
              r.numero.toLowerCase().contains(q) ||
              r.nombreCliente.toLowerCase().contains(q) ||
              (r.nombreMoto?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return lista;
  },
);

final paginacionReservasProvider = Provider<PaginacionReservas>(
  name: 'paginacionReservasProvider',
  (ref) {
    final filtradas = ref.watch(reservasFiltradasProvider);
    final paginaActual = ref.watch(
      reservasProvider.select((s) => s.asData?.value.paginaActual ?? 0),
    );

    const items = ReservasState.itemsPorPagina;
    final total = filtradas.length;
    final totalPaginas = (total / items).ceil().clamp(1, 9999);
    final inicio = paginaActual * items;
    final fin = (inicio + items).clamp(0, total);
    final paginadas =
        inicio >= total ? const <ReservaResumen>[] : filtradas.sublist(inicio, fin);

    return PaginacionReservas(
      paginadas: paginadas,
      paginaActual: paginaActual,
      totalPaginas: totalPaginas,
      totalFiltradas: total,
    );
  },
);
