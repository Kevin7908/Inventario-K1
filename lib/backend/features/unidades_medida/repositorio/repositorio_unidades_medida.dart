import '../../../../core/resultado.dart';
import '../modelo/unidad_medida.dart';

/// Las unidades en que se mide lo que vende el taller.
///
/// Las escrituras devuelven `Resultado` y no la entidad (`REGLAS_BD.md` §8):
/// el nombre repetido, la abreviatura repetida y el permiso que falta son
/// fallos esperables, y el texto lo decide la vista.
abstract class RepositorioUnidadesMedida {
  Future<List<UnidadMedida>> obtenerTodas();
  Future<UnidadMedida?> obtenerPorId(int id);
  Future<List<UnidadMedida>> buscarPorNombre(String consulta);
  Future<List<UnidadMedida>> obtenerPorTipo(String tipo);
  Future<Resultado> crear(UnidadMedida unidad);
  Future<Resultado> actualizar(UnidadMedida unidad);
  Future<Resultado> eliminar(int id);
  Future<bool> existeNombre(String nombre, {int? excludirId});
  Future<bool> existeAbreviatura(String abreviatura, {int? excludirId});
}
