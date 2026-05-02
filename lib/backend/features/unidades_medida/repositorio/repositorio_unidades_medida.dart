import '../modelo/unidad_medida.dart';

// Contrato abstracto del repositorio de unidades de medida
abstract class RepositorioUnidadesMedida {
  Future<List<UnidadMedida>> obtenerTodas();
  Future<UnidadMedida?> obtenerPorId(int id);
  Future<List<UnidadMedida>> buscarPorNombre(String consulta);
  Future<List<UnidadMedida>> obtenerPorTipo(String tipo);
  Future<UnidadMedida> crear(UnidadMedida unidad);
  Future<UnidadMedida> actualizar(UnidadMedida unidad);
  Future<void> eliminar(int id);
  Future<bool> existeNombre(String nombre, {int? excludirId});
  Future<bool> existeAbreviatura(String abreviatura, {int? excludirId});
}
