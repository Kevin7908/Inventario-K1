import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/backend/features/clientes/modelo/cliente.dart';
import 'package:inventario_k1/backend/features/clientes/repositorio/repositorio_cliente_impl.dart';
import 'package:inventario_k1/backend/features/deudores/enum/enum_deudor.dart';
import 'package:inventario_k1/backend/features/deudores/modelo/deudor_detalle.dart';
import 'package:inventario_k1/backend/features/deudores/modelo/deudor_resumen.dart';
import 'package:inventario_k1/backend/features/deudores/repositorio/repositorio_deudores.dart';
import 'package:inventario_k1/backend/features/deudores/repositorio/repositorio_deudores_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db_provider.dart';

// ── Repositorio ───────────────────────────────────────────────────────────────

final repositorioDeudoresProvider = Provider<RepositorioDeudores>(
  name: 'repositorioDeudoresProvider',
  (ref) => RepositorioDeudoresImpl(ref.watch(appDatabaseProvider)),
);

// ── Modos del panel ───────────────────────────────────────────────────────────

enum ModoPanelDeudor { vacio, detalle, formulario }

// ── Estado ────────────────────────────────────────────────────────────────────

final class DeudoresState {
  const DeudoresState({
    this.deudores = const [],
    this.filtroBusqueda = '',
    this.filtroEstado,
    this.paginaActual = 0,
    this.deudorSeleccionadoId,
    this.modoPanel = ModoPanelDeudor.vacio,
    this.mostrarFormPago = false,
  });

  final List<DeudorResumen> deudores;
  final String filtroBusqueda;
  final EstadoDeudor? filtroEstado;
  final int paginaActual;
  final int? deudorSeleccionadoId;
  final ModoPanelDeudor modoPanel;
  final bool mostrarFormPago;

  static const int itemsPorPagina = 15;

  static const Object _sentinel = Object();

  DeudoresState copyWith({
    List<DeudorResumen>? deudores,
    String? filtroBusqueda,
    Object? filtroEstado = _sentinel,
    int? paginaActual,
    Object? deudorSeleccionadoId = _sentinel,
    ModoPanelDeudor? modoPanel,
    bool? mostrarFormPago,
  }) {
    return DeudoresState(
      deudores: deudores ?? this.deudores,
      filtroBusqueda: filtroBusqueda ?? this.filtroBusqueda,
      filtroEstado: filtroEstado == _sentinel
          ? this.filtroEstado
          : filtroEstado as EstadoDeudor?,
      paginaActual: paginaActual ?? this.paginaActual,
      deudorSeleccionadoId: deudorSeleccionadoId == _sentinel
          ? this.deudorSeleccionadoId
          : deudorSeleccionadoId as int?,
      modoPanel: modoPanel ?? this.modoPanel,
      mostrarFormPago: mostrarFormPago ?? this.mostrarFormPago,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class DeudoresNotifier extends AsyncNotifier<DeudoresState> {
  late final RepositorioDeudores _repo;

  @override
  Future<DeudoresState> build() async {
    _repo = ref.watch(repositorioDeudoresProvider);

    final sub = _repo.observarTodas().listen(
      (lista) {
        final actual = state.value;
        state = AsyncData(
          actual != null
              ? actual.copyWith(deudores: lista)
              : DeudoresState(deudores: lista),
        );
      },
      onError: (Object e, StackTrace st) => state = AsyncError(e, st),
    );
    ref.onDispose(sub.cancel);

    final lista = await _repo.obtenerTodas();
    return DeudoresState(deudores: lista);
  }

  // ── Filtros y navegación ──────────────────────────────────────────────────

  void buscar(String q) {
    _mutate((s) => s.copyWith(filtroBusqueda: q.trim(), paginaActual: 0));
  }

  void filtrarEstado(EstadoDeudor? estado) {
    _mutate((s) => s.copyWith(filtroEstado: estado, paginaActual: 0));
  }

  void cambiarPagina(int pagina) {
    _mutate((s) => s.copyWith(paginaActual: pagina));
  }

  // ── Panel derecho ─────────────────────────────────────────────────────────

  void abrirDetalle(int deudorId) {
    _mutate((s) => s.copyWith(
          deudorSeleccionadoId: deudorId,
          modoPanel: ModoPanelDeudor.detalle,
          mostrarFormPago: false,
        ));
  }

  void abrirNuevo() {
    _mutate((s) => s.copyWith(
          deudorSeleccionadoId: null,
          modoPanel: ModoPanelDeudor.formulario,
          mostrarFormPago: false,
        ));
  }

  void abrirEditar(int deudorId) {
    _mutate((s) => s.copyWith(
          deudorSeleccionadoId: deudorId,
          modoPanel: ModoPanelDeudor.formulario,
          mostrarFormPago: false,
        ));
  }

  void cerrarPanel() {
    _mutate((s) => s.copyWith(
          deudorSeleccionadoId: null,
          modoPanel: ModoPanelDeudor.vacio,
          mostrarFormPago: false,
        ));
  }

  void toggleFormPago() {
    _mutate((s) => s.copyWith(mostrarFormPago: !s.mostrarFormPago));
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<String?> crear({
    required int clienteId,
    int? ventaId,
    required String concepto,
    required int montoTotal,
    String? fechaVencimiento,
    String? notas,
    int pagoInicial = 0,
    String metodoPagoInicial = 'Efectivo',
    String? notasPagoInicial,
  }) async {
    try {
      final id = await _repo.crear(
        clienteId: clienteId,
        ventaId: ventaId,
        concepto: concepto,
        montoTotal: montoTotal,
        fechaVencimiento: fechaVencimiento,
        notas: notas,
        pagoInicial: pagoInicial,
        metodoPagoInicial: metodoPagoInicial,
        notasPagoInicial: notasPagoInicial,
      );
      _mutate((s) => s.copyWith(
            deudorSeleccionadoId: id,
            modoPanel: ModoPanelDeudor.detalle,
          ));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> actualizar({
    required int id,
    int? ventaId,
    required String concepto,
    required int montoTotal,
    String? fechaVencimiento,
    String? notas,
    required EstadoDeudor estado,
  }) async {
    try {
      await _repo.actualizar(
        id: id,
        ventaId: ventaId,
        concepto: concepto,
        montoTotal: montoTotal,
        fechaVencimiento: fechaVencimiento,
        notas: notas,
        estado: estado,
      );
      _mutate((s) => s.copyWith(
            deudorSeleccionadoId: id,
            modoPanel: ModoPanelDeudor.detalle,
          ));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> registrarPago({
    required int deudorId,
    required int monto,
    required String metodoPago,
    String? notas,
  }) async {
    try {
      await _repo.registrarPago(
        deudorId: deudorId,
        monto: monto,
        metodoPago: metodoPago,
        notas: notas,
      );
      _mutate((s) => s.copyWith(mostrarFormPago: false));
      ref.invalidate(deudorDetalleProvider(deudorId));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> eliminarPago(int pagoId, int deudorId) async {
    try {
      await _repo.eliminarPago(pagoId, deudorId);
      ref.invalidate(deudorDetalleProvider(deudorId));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> cambiarEstado(int id, EstadoDeudor nuevoEstado) async {
    try {
      await _repo.cambiarEstado(id, nuevoEstado);
      ref.invalidate(deudorDetalleProvider(id));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> eliminar(int id) async {
    final actual = state.value;
    if (actual == null) return null;

    final snapshot = actual.deudores;
    _mutate((s) => s.copyWith(
          deudores: snapshot.where((d) => d.id != id).toList(growable: false),
          deudorSeleccionadoId: null,
          modoPanel: ModoPanelDeudor.vacio,
        ));
    try {
      await _repo.eliminar(id);
      return null;
    } catch (e) {
      _mutate((s) => s.copyWith(deudores: snapshot));
      return e.toString();
    }
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  void _mutate(DeudoresState Function(DeudoresState) fn) {
    final actual = state.value;
    if (actual == null) return;
    state = AsyncData(fn(actual));
  }
}

// ── Providers públicos ────────────────────────────────────────────────────────

final deudoresProvider =
    AsyncNotifierProvider<DeudoresNotifier, DeudoresState>(
  DeudoresNotifier.new,
  name: 'deudoresProvider',
);

final deudorDetalleProvider =
    FutureProvider.autoDispose.family<DeudorDetalle, int>(
  name: 'deudorDetalleProvider',
  (ref, id) => ref.watch(repositorioDeudoresProvider).obtenerDetalle(id),
);

final clientesParaDeudorProvider = FutureProvider<List<Cliente>>(
  name: 'clientesParaDeudorProvider',
  (ref) =>
      RepositorioClientesImpl(ref.watch(appDatabaseProvider)).obtenerTodos(),
);

/// Deuda vinculada a una venta/factura específica.
/// Se actualiza reactivamente cuando cambia la lista de deudores.
final deudorPorVentaProvider = Provider.family<DeudorResumen?, int>(
  name: 'deudorPorVentaProvider',
  (ref, ventaId) {
    final lista = ref.watch(
      deudoresProvider.select((s) => s.asData?.value.deudores ?? const []),
    );
    for (final d in lista) {
      if (d.ventaId == ventaId) return d;
    }
    return null;
  },
);

// ── Modelos derivados ─────────────────────────────────────────────────────────

final class DeudoresMetrics {
  const DeudoresMetrics({
    required this.carteraTotal,
    required this.saldoPorCobrar,
    required this.cantActivas,
    required this.cantVencidas,
  });

  final int carteraTotal;
  final int saldoPorCobrar;
  final int cantActivas;
  final int cantVencidas;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeudoresMetrics &&
          carteraTotal == other.carteraTotal &&
          saldoPorCobrar == other.saldoPorCobrar &&
          cantActivas == other.cantActivas &&
          cantVencidas == other.cantVencidas;

  @override
  int get hashCode =>
      Object.hash(carteraTotal, saldoPorCobrar, cantActivas, cantVencidas);
}

final class PaginacionDeudores {
  const PaginacionDeudores({
    required this.paginadas,
    required this.paginaActual,
    required this.totalPaginas,
    required this.totalFiltradas,
  });

  final List<DeudorResumen> paginadas;
  final int paginaActual;
  final int totalPaginas;
  final int totalFiltradas;

  // Igualdad profunda: Riverpod no notifica a _ListaDeudores si la página visible no cambió
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginacionDeudores &&
          paginaActual == other.paginaActual &&
          totalPaginas == other.totalPaginas &&
          totalFiltradas == other.totalFiltradas &&
          listEquals(paginadas, other.paginadas);

  @override
  int get hashCode =>
      Object.hash(paginaActual, totalPaginas, totalFiltradas, paginadas.length);
}

// ── Providers derivados ───────────────────────────────────────────────────────

final deudoresMetricsProvider = Provider<DeudoresMetrics>(
  name: 'deudoresMetricsProvider',
  (ref) {
    final lista = ref.watch(
      deudoresProvider.select((s) => s.asData?.value.deudores ?? const []),
    );
    final cartera = lista.fold(0, (s, d) => s + d.montoTotal);
    final porCobrar = lista
        .where((d) => d.estado != EstadoDeudor.pagada)
        .fold(0, (s, d) => s + d.saldo);
    return DeudoresMetrics(
      carteraTotal: cartera,
      saldoPorCobrar: porCobrar,
      cantActivas: lista.where((d) => d.estado == EstadoDeudor.activa).length,
      cantVencidas:
          lista.where((d) => d.estado == EstadoDeudor.vencida).length,
    );
  },
);

final deudoresFiltradasProvider = Provider<List<DeudorResumen>>(
  name: 'deudoresFiltradasProvider',
  (ref) {
    final p = ref.watch(deudoresProvider.select((s) {
      final v = s.asData?.value;
      if (v == null) {
        return (
          lista: <DeudorResumen>[],
          estado: null as EstadoDeudor?,
          busqueda: '',
        );
      }
      return (lista: v.deudores, estado: v.filtroEstado, busqueda: v.filtroBusqueda);
    }));

    var lista = p.lista;
    if (p.estado != null) {
      lista = lista.where((d) => d.estado == p.estado).toList();
    }
    final q = p.busqueda.toLowerCase();
    if (q.isNotEmpty) {
      lista = lista
          .where((d) =>
              d.numero.toLowerCase().contains(q) ||
              d.nombreCliente.toLowerCase().contains(q) ||
              d.concepto.toLowerCase().contains(q))
          .toList();
    }
    return lista;
  },
);

final paginacionDeudoresProvider = Provider<PaginacionDeudores>(
  name: 'paginacionDeudoresProvider',
  (ref) {
    final filtradas = ref.watch(deudoresFiltradasProvider);
    final paginaActual = ref.watch(
      deudoresProvider.select((s) => s.asData?.value.paginaActual ?? 0),
    );

    const items = DeudoresState.itemsPorPagina;
    final total = filtradas.length;
    final totalPaginas = (total / items).ceil().clamp(1, 9999);
    final inicio = paginaActual * items;
    final fin = (inicio + items).clamp(0, total);
    final paginadas =
        inicio >= total ? const <DeudorResumen>[] : filtradas.sublist(inicio, fin);

    return PaginacionDeudores(
      paginadas: paginadas,
      paginaActual: paginaActual,
      totalPaginas: totalPaginas,
      totalFiltradas: total,
    );
  },
);
