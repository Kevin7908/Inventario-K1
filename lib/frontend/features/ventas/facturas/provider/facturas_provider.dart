import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../../../../backend/features/ventas/facturas/modelo/factura_detalle.dart';
import '../../../../../backend/features/ventas/facturas/modelo/factura_resumen.dart';
import '../../../../../backend/features/ventas/facturas/repositorio/repositorio_facturas.dart';
import '../../../../../backend/features/ventas/facturas/repositorio/repositorio_facturas_impl.dart';
import '../../../../../backend/share/database/app_db_provider.dart';
import '../../ordenes/provider/ordenes_provider.dart';

final repositorioFacturasProvider = Provider<RepositorioFacturas>(
  name: 'repositorioFacturasProvider',
  (ref) => RepositorioFacturasImpl(ref.watch(appDatabaseProvider)),
);

// ── State ────────────────────────────────────────────────────────────────────

final class FacturasState {
  const FacturasState({
    this.facturas        = const [],
    this.filtroBusqueda  = '',
    this.filtroEstadoPago,
  });

  final List<FacturaResumen> facturas;
  final String               filtroBusqueda;
  final EstadoPago?          filtroEstadoPago;

  FacturasState copyWith({
    List<FacturaResumen>? facturas,
    String?               filtroBusqueda,
    Object?               filtroEstadoPago = _sentinel,
  }) =>
      FacturasState(
        facturas:        facturas        ?? this.facturas,
        filtroBusqueda:  filtroBusqueda  ?? this.filtroBusqueda,
        filtroEstadoPago: filtroEstadoPago == _sentinel
            ? this.filtroEstadoPago
            : filtroEstadoPago as EstadoPago?,
      );

  static const Object _sentinel = Object();
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class FacturasNotifier extends AsyncNotifier<FacturasState> {
  late final RepositorioFacturas _repo;

  @override
  Future<FacturasState> build() async {
    _repo = ref.watch(repositorioFacturasProvider);

    final sub = _repo.observarTodas().listen(
      (lista) {
        final actual = state.value;
        state = AsyncData(
          actual != null
              ? actual.copyWith(facturas: lista)
              : FacturasState(facturas: lista),
        );
      },
      onError: (Object e, StackTrace st) => state = AsyncError(e, st),
    );
    ref.onDispose(sub.cancel);

    final lista = await _repo.obtenerTodas();
    return FacturasState(facturas: lista);
  }

  // ── Filtros ───────────────────────────────────────────────────────────────

  void buscar(String query) {
    final actual = state.value;
    if (actual == null) return;
    state = AsyncData(actual.copyWith(filtroBusqueda: query.trim()));
  }

  void filtrarEstadoPago(EstadoPago? estado) {
    final actual = state.value;
    if (actual == null) return;
    state = AsyncData(actual.copyWith(filtroEstadoPago: estado));
  }

  // ── CRUD Factura ──────────────────────────────────────────────────────────

  Future<String?> crear({
    required TipoVenta tipo,
    int? ordenId,
    int? clienteId,
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    double iva = 0,
  }) async {
    try {
      await _repo.crear(
        tipo:        tipo,
        ordenId:     ordenId,
        clienteId:   clienteId,
        metodoPago:  metodoPago,
        estadoPago:  estadoPago,
        iva:         iva,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> crearDesdeOrden({
    required int ordenId,
    required int clienteId,
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    double iva = 0,
  }) async {
    try {
      await _repo.crearDesdeOrden(
        ordenId:    ordenId,
        clienteId:  clienteId,
        metodoPago: metodoPago,
        estadoPago: estadoPago,
        iva:        iva,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> actualizarDesdeOrden({
    required int facturaId,
    required int ordenId,
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    double iva = 0,
  }) async {
    try {
      final factura = await _repo.actualizarDesdeOrden(
        facturaId:  facturaId,
        ordenId:    ordenId,
        metodoPago: metodoPago,
        estadoPago: estadoPago,
        iva:        iva,
      );
      ref.invalidate(facturaDetalleProvider(factura.id));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> actualizar({
    required int id,
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    double? iva,
  }) async {
    try {
      await _repo.actualizar(
        id:         id,
        metodoPago: metodoPago,
        estadoPago: estadoPago,
        iva:        iva,
      );
      ref.invalidate(facturaDetalleProvider(id));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> eliminar(int id) async {
    final actual = state.value;
    if (actual == null) return null;

    final snapshot = actual.facturas;
    state = AsyncData(
      actual.copyWith(
        facturas: snapshot.where((f) => f.id != id).toList(growable: false),
      ),
    );
    try {
      await _repo.eliminar(id);
      return null;
    } catch (e) {
      state = AsyncData(actual.copyWith(facturas: snapshot));
      return e.toString();
    }
  }

  // ── CRUD Items ────────────────────────────────────────────────────────────

  Future<String?> agregarItem({
    required int ventaId,
    required TipoItem tipoItem,
    int? productoId,
    int? servicioId,
    int? tecnicoId,
    required String descripcion,
    required double cantidad,
    required double precioUnitario,
    double costoUnitario = 0,
  }) async {
    try {
      await _repo.agregarItem(
        ventaId:        ventaId,
        tipoItem:       tipoItem,
        productoId:     productoId,
        servicioId:     servicioId,
        tecnicoId:      tecnicoId,
        descripcion:    descripcion,
        cantidad:       cantidad,
        precioUnitario: precioUnitario,
        costoUnitario:  costoUnitario,
      );
      ref.invalidate(facturaDetalleProvider(ventaId));
      _invalidarOrdenSiExiste(ventaId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> actualizarItem(
    int itemId,
    int ventaId, {
    double? cantidad,
    double? precioUnitario,
  }) async {
    try {
      await _repo.actualizarItem(itemId, cantidad: cantidad, precioUnitario: precioUnitario);
      ref.invalidate(facturaDetalleProvider(ventaId));
      _invalidarOrdenSiExiste(ventaId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> eliminarItem(int itemId, int ventaId) async {
    try {
      await _repo.eliminarItem(itemId);
      ref.invalidate(facturaDetalleProvider(ventaId));
      _invalidarOrdenSiExiste(ventaId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  void _invalidarOrdenSiExiste(int ventaId) {
    final facturas = state.value?.facturas ?? const [];
    for (final f in facturas) {
      if (f.id == ventaId && f.ordenId != null) {
        ref.invalidate(ordenDetalleProvider(f.ordenId!));
        break;
      }
    }
  }
}

// ── Providers públicos ────────────────────────────────────────────────────────

final facturasProvider =
    AsyncNotifierProvider<FacturasNotifier, FacturasState>(
  FacturasNotifier.new,
  name: 'facturasProvider',
);

// Lista filtrada de TODAS las facturas
final facturasFiltradas = Provider<List<FacturaResumen>>(
  name: 'facturasFiltradas',
  (ref) {
    final estado = ref.watch(facturasProvider).value;
    if (estado == null) return const [];
    return _aplicarFiltros(estado.facturas, estado);
  },
);

// Lista filtrada solo SERVICIO (Facturación)
final facturasServicioFiltradas = Provider<List<FacturaResumen>>(
  name: 'facturasServicioFiltradas',
  (ref) {
    final estado = ref.watch(facturasProvider).value;
    if (estado == null) return const [];
    final solo = estado.facturas
        .where((f) => f.tipo == TipoVenta.servicio)
        .toList(growable: false);
    return _aplicarFiltros(solo, estado);
  },
);

// Lista filtrada solo MOSTRADOR (Venta Rápida)
final facturasRapidaFiltradas = Provider<List<FacturaResumen>>(
  name: 'facturasRapidaFiltradas',
  (ref) {
    final estado = ref.watch(facturasProvider).value;
    if (estado == null) return const [];
    final solo = estado.facturas
        .where((f) => f.tipo == TipoVenta.mostrador)
        .toList(growable: false);
    return _aplicarFiltros(solo, estado);
  },
);

List<FacturaResumen> _aplicarFiltros(
  List<FacturaResumen> lista,
  FacturasState estado,
) {
  var result = lista;

  final filtro = estado.filtroEstadoPago;
  if (filtro != null) {
    result = result.where((f) => f.estadoPago == filtro).toList(growable: false);
  }

  final q = estado.filtroBusqueda.toLowerCase();
  if (q.isNotEmpty) {
    result = result.where((f) {
      return f.numeroFactura.toLowerCase().contains(q) ||
          f.clienteNombre.toLowerCase().contains(q) ||
          (f.numeroOrden?.toLowerCase().contains(q) ?? false);
    }).toList(growable: false);
  }

  return result;
}

final facturaDetalleProvider = FutureProvider.family<FacturaDetalle, int>(
  name: 'facturaDetalleProvider',
  (ref, id) => ref.watch(repositorioFacturasProvider).obtenerDetalle(id),
);

final facturaDeOrdenProvider = Provider.family<FacturaResumen?, int>(
  name: 'facturaDeOrdenProvider',
  (ref, ordenId) {
    final facturas = ref.watch(facturasProvider).value?.facturas;
    if (facturas == null) return null;
    for (final f in facturas) {
      if (f.ordenId == ordenId) return f;
    }
    return null;
  },
);
