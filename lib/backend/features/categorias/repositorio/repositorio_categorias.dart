import 'package:inventario_k1/backend/features/categorias/modelo/categoria.dart';

/// Una página de categorías junto al total de coincidencias.
///
/// [total] cuenta todas las filas que cumplen el filtro, no las de la página.
class PaginaCategorias {
  const PaginaCategorias({required this.items, required this.total});

  final List<Categoria> items;
  final int total;

  static const vacia = PaginaCategorias(items: [], total: 0);
}

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

  /// Observa una página de categorías cuyo nombre contenga [busqueda].
  ///
  /// [pagina] es de base cero. El filtrado, el conteo y el recorte los hace
  /// SQLite; la vista nunca recibe el catálogo entero.
  Stream<PaginaCategorias> observarPagina({
    String busqueda = '',
    required int pagina,
    required int tamano,
  });
}
