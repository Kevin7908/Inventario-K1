// backend/features/especializaciones/repositorio/repositorio_especializacion.dart

import '../modelo/especializacion.dart';

abstract interface class RepositorioEspecializacion {

  Stream<List<Especializacion>> observarTodas();

  /// Snapshot puntual — útil para validaciones asíncronas.
  Future<List<Especializacion>> obtenerTodas();

  Future<bool> existeNombre(String nombre, {int? ignorarId});

  Future<Especializacion> agregar({
    required String nombre,
    String? descripcion,
  });

  Future<Especializacion> actualizar({
    required int id,
    required String nombre,
    String? descripcion,
  });

  Future<void> eliminar(int id);
}