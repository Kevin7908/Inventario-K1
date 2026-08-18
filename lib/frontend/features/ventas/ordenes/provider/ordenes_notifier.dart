import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/ventas/ordenes/enum/enum_ordenes.dart';
import '../../../../../backend/features/ventas/ordenes/repositorio/repositrio_ordenes.dart';
import 'ordenes_providers.dart';
import 'ordenes_state.dart';

class OrdenesNotifier extends AsyncNotifier<OrdenesState> {
  late final RepositorioOrdenes _repo;

  @override
  Future<OrdenesState> build() async {
    _repo = ref.watch(repositorioOrdenesProvider);

    final sub = _repo.observarTodas().listen(
      (lista) {
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

    final lista = await _repo.obtenerTodas();
    return OrdenesState(ordenes: lista);
  }

  // ── Filtros ────────────────────────────────────────────────────────────────

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

  // ── Orden CRUD ────────────────────────────────────────────────────────────

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

  Future<String?> eliminar(int id) async {
    final actual = state.value;
    if (actual == null) return null;

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
      state = AsyncData(actual.copyWith(ordenes: snapshot));
      return e.toString();
    }
  }

  // ── Tareas ────────────────────────────────────────────────────────────────

  Future<String?> agregarTarea(
    int ordenId, {
    required int    servicioId,
    required int    tecnicoId,
    required int precioPactado,
    String?         notas,
  }) async {
    try {
      await _repo.agregarTarea(
        ordenId:       ordenId,
        servicioId:    servicioId,
        tecnicoId:     tecnicoId,
        precioPactado: precioPactado,
        notas:         notas,
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
    int?    servicioId,
    int?    tecnicoId,
    int? precioPactado,
    String? notas,
    bool?   completado,
  }) async {
    try {
      await _repo.actualizarTarea(
        tareaId,
        servicioId:    servicioId,
        tecnicoId:     tecnicoId,
        precioPactado: precioPactado,
        notas:         notas,
        completado:    completado,
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

  // ── Repuestos ─────────────────────────────────────────────────────────────

  Future<String?> agregarRepuesto(
    int ordenId, {
    required int    productoId,
    required double cantidad,
    required int precioUnitario,
  }) async {
    try {
      await _repo.agregarRepuesto(
        ordenId:        ordenId,
        productoId:     productoId,
        cantidad:       cantidad,
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
    int? precioUnitario,
  }) async {
    try {
      await _repo.actualizarRepuesto(
        repuestoId,
        cantidad:       cantidad,
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
}
