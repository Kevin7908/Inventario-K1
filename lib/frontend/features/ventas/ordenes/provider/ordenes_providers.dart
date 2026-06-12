import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/ventas/ordenes/enum/enum_ordenes.dart';
import '../../../../../backend/features/ventas/ordenes/modelo/orden_detalle.dart';
import '../../../../../backend/features/ventas/ordenes/modelo/orden_resumen.dart';
import '../../../../../backend/features/ventas/ordenes/repositorio/repositrio_ordenes.dart';
import '../../../../../backend/features/ventas/ordenes/repositorio/repositrio_ordenes_impl.dart';
import '../../../../../backend/share/database/app_db_provider.dart';
import 'ordenes_notifier.dart';
import 'ordenes_state.dart';

// ── Repositorio ───────────────────────────────────────────────────────────────

final repositorioOrdenesProvider = Provider<RepositorioOrdenes>(
  name: 'repositorioOrdenesProvider',
  (ref) => RepositorioOrdenesImpl(ref.watch(appDatabaseProvider)),
);

// ── Notifier principal ────────────────────────────────────────────────────────

final ordenesProvider = AsyncNotifierProvider<OrdenesNotifier, OrdenesState>(
  OrdenesNotifier.new,
  name: 'ordenesProvider',
);

// ── Selector: lista filtrada ──────────────────────────────────────────────────

final ordenesFiltradas = Provider<List<OrdenResumen>>(
  name: 'ordenesFiltradas',
  (ref) {
    final estado = ref.watch(ordenesProvider).value;
    if (estado == null) return const [];

    var lista = estado.ordenes;

    final filtro = estado.filtroEstado;
    if (filtro != null) {
      lista = lista.where((o) => o.estado == filtro).toList(growable: false);
    }

    final q = estado.filtroBusqueda.toLowerCase();
    if (q.isEmpty) return lista;

    return lista.where((o) {
      return o.numeroOrden.toLowerCase().contains(q)     ||
             o.motoDescripcion.toLowerCase().contains(q) ||
             o.clienteNombre.toLowerCase().contains(q)   ||
             (o.diagnostico?.toLowerCase().contains(q) ?? false);
    }).toList(growable: false);
  },
);

// ── Selector: contadores por estado ──────────────────────────────────────────

final ordenesContadoresProvider =
    Provider<({int abiertas, int listas, int total})>(
  name: 'ordenesContadoresProvider',
  (ref) {
    final ordenes = ref.watch(ordenesProvider).value?.ordenes ?? const [];
    return (
      abiertas: ordenes.where((o) => o.estado == EstadoOrden.abierta).length,
      listas:   ordenes.where((o) => o.estado == EstadoOrden.lista).length,
      total:    ordenes.length,
    );
  },
);

// ── Detalle de una orden ──────────────────────────────────────────────────────

final ordenDetalleProvider = FutureProvider.family<OrdenDetalle, int>(
  name: 'ordenDetalleProvider',
  (ref, id) => ref.watch(repositorioOrdenesProvider).obtenerDetalle(id),
);
