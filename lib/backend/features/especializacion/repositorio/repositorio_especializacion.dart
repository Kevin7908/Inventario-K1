// backend/features/especializaciones/repositorio/repositorio_especializacion.dart

import '../../../../core/resultado.dart';
import '../modelo/especializacion.dart';

/// Las especializaciones que puede tener un técnico.
///
/// Las escrituras devuelven `Resultado` y no la entidad (`REGLAS_BD.md` §8):
/// el nombre repetido y el permiso que falta son fallos esperables, y el texto
/// lo decide la vista.
abstract interface class RepositorioEspecializacion {

  Stream<List<Especializacion>> observarTodas();

  /// Snapshot puntual — útil para validaciones asíncronas.
  Future<List<Especializacion>> obtenerTodas();

  Future<bool> existeNombre(String nombre, {int? ignorarId});

  Future<Resultado> agregar({
    required String nombre,
    String? descripcion,
  });

  Future<Resultado> actualizar({
    required int id,
    required String nombre,
    String? descripcion,
  });

  Future<Resultado> eliminar(int id);
}
