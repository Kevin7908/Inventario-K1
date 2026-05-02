import 'package:inventario_k1/backend/features/categorias/modelo/categoria.dart';

// Contrato abstracto del repositorio de categorías
// El ViewModel depende de esta abstracción, no de la implementación concreta
abstract class RepositorioCategorias {
  // Obtener todas las categorías
  Stream<List<Categoria>> observarTodas();

  // Obtener una categoría por su ID
  Future<Categoria?> obtenerPorId(int id);

  // Buscar categorías por nombre
  Future<List<Categoria>> buscarPorNombre(String consulta);

  // Crear una nueva categoría
  Future<Categoria> crear(Categoria categoria);

  // Actualizar una categoría existente
  Future<Categoria> actualizar(Categoria categoria);

  // Eliminar una categoría por su ID
  Future<void> eliminar(int id);

  // Verificar si el nombre ya existe (para validación)
  Future<bool> existeNombre(String nombre, {int? excludirId});
}
