import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../../../../backend/features/ventas/facturas/modelo/factura_detalle.dart';
import '../../../../../backend/features/ventas/facturas/modelo/factura_resumen.dart';
import '../../../../../backend/features/ventas/facturas/repositorio/repositorio_facturas.dart';
import '../../../../../backend/features/ventas/facturas/repositorio/repositorio_facturas_impl.dart';
import '../../../../../backend/share/database/app_db_provider.dart';
import 'facturas_notifier.dart';
import 'facturas_state.dart';

// ── Repositorio ───────────────────────────────────────────────────────────────

final repositorioFacturasProvider = Provider<RepositorioFacturas>(
  name: 'repositorioFacturasProvider',
  (ref) => RepositorioFacturasImpl(ref.watch(appDatabaseProvider)),
);

// ── Notifier principal ────────────────────────────────────────────────────────

final facturasProvider =
    AsyncNotifierProvider<FacturasNotifier, FacturasState>(
  FacturasNotifier.new,
  name: 'facturasProvider',
);

// ── Selectores ────────────────────────────────────────────────────────────────

/// Todas las facturas con filtros aplicados.
final facturasFiltradas = Provider<List<FacturaResumen>>(
  name: 'facturasFiltradas',
  (ref) {
    final estado = ref.watch(facturasProvider).value;
    if (estado == null) return const [];
    return _aplicarFiltros(estado.facturas, estado);
  },
);

/// Solo facturas de servicio (tab Facturación).
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

/// Solo facturas de mostrador (tab Venta Rápida — historial).
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

/// Factura asociada a una orden (para el panel resumen).
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

/// KPIs de facturación (solo servicio).
final facturasKpisProvider = Provider<({
  double totalMes,
  double pendiente,
  double cobrado,
  int count,
})>(
  name: 'facturasKpisProvider',
  (ref) {
    final facturas = ref.watch(facturasProvider).value?.facturas ?? const [];
    final servicio = facturas.where((f) => f.tipo == TipoVenta.servicio);
    final ahora    = DateTime.now();

    double totalMes  = 0;
    double pendiente = 0;
    double cobrado   = 0;
    int    count     = 0;

    for (final f in servicio) {
      count++;
      if (f.estadoPago == EstadoPago.pendiente) pendiente += f.total;
      if (f.estadoPago == EstadoPago.pagado) {
        cobrado += f.total;
        if (f.creadoEn != null &&
            f.creadoEn!.month == ahora.month &&
            f.creadoEn!.year  == ahora.year) {
          totalMes += f.total;
        }
      }
    }
    return (totalMes: totalMes, pendiente: pendiente, cobrado: cobrado, count: count);
  },
);

// ── Detalle de una factura ────────────────────────────────────────────────────

final facturaDetalleProvider = FutureProvider.family<FacturaDetalle, int>(
  name: 'facturaDetalleProvider',
  (ref, id) => ref.watch(repositorioFacturasProvider).obtenerDetalle(id),
);

// ── Helpers privados ──────────────────────────────────────────────────────────

List<FacturaResumen> _aplicarFiltros(
  List<FacturaResumen> lista,
  FacturasState estado,
) {
  var result = lista;

  final filtro = estado.filtroEstadoPago;
  if (filtro != null) {
    result = result
        .where((f) => f.estadoPago == filtro)
        .toList(growable: false);
  }

  final q = estado.filtroBusqueda.toLowerCase();
  if (q.isNotEmpty) {
    result = result.where((f) {
      return f.numeroFactura.toLowerCase().contains(q) ||
          f.clienteNombre.toLowerCase().contains(q)    ||
          (f.numeroOrden?.toLowerCase().contains(q) ?? false);
    }).toList(growable: false);
  }

  return result;
}
