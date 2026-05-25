import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/ventas/ordenes/enum/enum_ordenes.dart';
import '../../../../../backend/features/ventas/ordenes/modelo/orden_detalle.dart';
import '../../../../../backend/features/ventas/ordenes/modelo/orden_resumen.dart';
import '../../../../../backend/features/ventas/ordenes/repositorio/repositrio_ordenes.dart';
import '../../../../../backend/features/ventas/ordenes/repositorio/repositrio_ordenes_impl.dart';
import '../../../../../backend/share/database/app_db_provider.dart';

final repositorioOrdenesProvider = Provider<RepositorioOrdenes>(
  name: 'repositorioOrdenesProvider',
  (ref) => RepositorioOrdenesImpl(ref.watch(appDatabaseProvider)),
);

final class OrdenesState {
  const OrdenesState({
    this.ordenes       = const [],
    this.filtroBusqueda = '',
    this.filtroEstado,
  });

  final List<OrdenResumen> ordenes;
  final String             filtroBusqueda;
  final EstadoOrden?       filtroEstado; 

  OrdenesState copyWith({
    List<OrdenResumen>? ordenes,
    String?             filtroBusqueda,
    Object?             filtroEstado = _sentinel,
  }) =>
      OrdenesState(
        ordenes:        ordenes        ?? this.ordenes,
        filtroBusqueda: filtroBusqueda ?? this.filtroBusqueda,
        filtroEstado:   filtroEstado == _sentinel
            ? this.filtroEstado
            : filtroEstado as EstadoOrden?,
      );

  static const Object _sentinel = Object();
}

class OrdenesNotifier extends AsyncNotifier<OrdenesState> {
  late final RepositorioOrdenes _repo;

  @override
  Future<OrdenesState> build() async {
    _repo = ref.watch(repositorioOrdenesProvider);

    // se cancela automáticamente al dispose del provider.
    final sub = _repo.observarTodas().listen(
      (lista) {
        // Mantiene filtros activos al recibir cambios del stream.
        final actual = state.value;
        state = AsyncData(
          actual != null
              ? actual.copyWith(ordenes: lista)
              : OrdenesState(ordenes: lista),
        );
      },
      onError: (Object e, StackTrace st) => state = AsyncError(e, st),
    );
    ref.onDispose(sub.cancel);

    // Carga inicial 
    final lista = await _repo.obtenerTodas();
    return OrdenesState(ordenes: lista);
  }

  // Filtros 

  void buscar(String query) {
    final actual = state.value;
    if (actual == null) return;
    state = AsyncData(actual.copyWith(filtroBusqueda: query.trim()));
  }

  void filtrarEstado(EstadoOrden? estado) {
    final actual = state.value;
    if (actual == null) return;
    state = AsyncData(actual.copyWith(filtroEstado: estado));
  }

  // Retorna null en éxito o el mensaje de error como String.
  Future<String?> agregar({
    required int    motoId,
    required int    clienteId,
    required int    kilometrajeEntrada,
    String?         diagnostico,
    String?         observaciones,
  }) async {
    try {
      await _repo.agregar(
        motoId:             motoId,
        clienteId:          clienteId,
        kilometrajeEntrada: kilometrajeEntrada,
        diagnostico:        diagnostico,
        observaciones:      observaciones,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> cambiarEstado(int id, EstadoOrden nuevoEstado) async {
    final actual = state.value;
    if (actual == null) return null;

    try {
      final orden = actual.ordenes.firstWhere(
        (o) => o.id == id,
        orElse: () => throw Exception('Orden #$id no encontrada'),
      );
      await _repo.actualizar(
        id:                  id,
        estado:              nuevoEstado,
        kilometrajeEntrada:  orden.kilometrajeEntrada,
        diagnostico:         orden.diagnostico,
        observaciones:       null,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> actualizarOrden(
    int id, {
    required EstadoOrden estado,
    required int kilometrajeEntrada,
    int? motoId,
    int? clienteId,
    String? diagnostico,
    String? observaciones,
  }) async {
    try {
      await _repo.actualizar(
        id:                 id,
        estado:             estado,
        kilometrajeEntrada: kilometrajeEntrada,
        motoId:             motoId,
        clienteId:          clienteId,
        diagnostico:        diagnostico,
        observaciones:      observaciones,
      );
      ref.invalidate(ordenDetalleProvider(id));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> agregarTarea(
    int ordenId, {
    required int servicioId,
    required int tecnicoId,
    required double precioPactado,
    String? notas,
  }) async {
    try {
      await _repo.agregarTarea(
        ordenId: ordenId,
        servicioId: servicioId,
        tecnicoId: tecnicoId,
        precioPactado: precioPactado,
        notas: notas,
      );
      ref.invalidate(ordenDetalleProvider(ordenId));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> actualizarTarea(
    int tareaId,
    int ordenId, {
    int? servicioId,
    int? tecnicoId,
    double? precioPactado,
    String? notas,
    bool? completado,
  }) async {
    try {
      await _repo.actualizarTarea(
        tareaId,
        servicioId: servicioId,
        tecnicoId: tecnicoId,
        precioPactado: precioPactado,
        notas: notas,
        completado: completado,
      );
      ref.invalidate(ordenDetalleProvider(ordenId));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> eliminarTarea(int tareaId, int ordenId) async {
    try {
      await _repo.eliminarTarea(tareaId);
      ref.invalidate(ordenDetalleProvider(ordenId));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> agregarRepuesto(
    int ordenId, {
    required int productoId,
    required double cantidad,
    required double precioUnitario,
  }) async {
    try {
      await _repo.agregarRepuesto(
        ordenId: ordenId,
        productoId: productoId,
        cantidad: cantidad,
        precioUnitario: precioUnitario,
      );
      ref.invalidate(ordenDetalleProvider(ordenId));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> actualizarRepuesto(
    int repuestoId,
    int ordenId, {
    double? cantidad,
    double? precioUnitario,
  }) async {
    try {
      await _repo.actualizarRepuesto(
        repuestoId,
        cantidad: cantidad,
        precioUnitario: precioUnitario,
      );
      ref.invalidate(ordenDetalleProvider(ordenId));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> eliminarRepuesto(int repuestoId, int ordenId) async {
    try {
      await _repo.eliminarRepuesto(repuestoId);
      ref.invalidate(ordenDetalleProvider(ordenId));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> eliminar(int id) async {
    final actual = state.value;
    if (actual == null) return null;

    // Optimistic update: quita la orden de la lista antes de llamar a la BD.
    final snapshot = actual.ordenes;
    state = AsyncData(
      actual.copyWith(
        ordenes: snapshot.where((o) => o.id != id).toList(growable: false),
      ),
    );

    try {
      await _repo.eliminar(id);
      return null;
    } catch (e) {
      // Rollback si la BD falla.
      state = AsyncData(actual.copyWith(ordenes: snapshot));
      return e.toString();
    }
  }
}

// Provider de la lista, autoDispose para liberar cuando no hay listeners.
final ordenesProvider = AsyncNotifierProvider<OrdenesNotifier, OrdenesState>(
  OrdenesNotifier.new,
  name: 'ordenesProvider',
);

final ordenesFiltradas = Provider<List<OrdenResumen>>(
  name: 'ordenesFiltradas',
  (ref) {
    final estado = ref.watch(ordenesProvider).value;
    if (estado == null) return const [];

    var lista = estado.ordenes;

    // Filtro por chip de estado
    final filtro = estado.filtroEstado;
    if (filtro != null) {
      lista = lista.where((o) => o.estado == filtro).toList(growable: false);
    }

    // Filtro de búsqueda por texto
    final q = estado.filtroBusqueda.toLowerCase();
    if (q.isEmpty) return lista;

    return lista.where((o) {
      return o.numeroOrden.toLowerCase().contains(q)      ||
             o.motoDescripcion.toLowerCase().contains(q)  ||
             o.clienteNombre.toLowerCase().contains(q)    ||
             (o.diagnostico?.toLowerCase().contains(q) ?? false);
    }).toList(growable: false);
  },
);

final ordenDetalleProvider = FutureProvider.family<OrdenDetalle, int>(
  name: 'ordenDetalleProvider',
  (ref, id) => ref.watch(repositorioOrdenesProvider).obtenerDetalle(id),
);