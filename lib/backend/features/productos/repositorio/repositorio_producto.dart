import '../modelo/producto.dart';

/// Contrato abstracto del repositorio de productos.
/// El ViewModel depende de esta abstracción, nunca de la implementación concreta.
abstract class RepositorioProducto {
  /// Observa todos los productos en tiempo real (Stream reactivo).
  Stream<List<Producto>> observarTodos();

  /// Observa solo los productos con stock bajo (stockActual <= stockMinimo).
  Stream<List<Producto>> observarConStockBajo();

  /// Obtiene todos los productos (consulta única, no reactiva).
  Future<List<Producto>> obtenerTodos();

  /// Obtiene un producto por su ID. Retorna null si no existe.
  Future<Producto?> obtenerPorId(int id);

  /// Obtiene un producto por su SKU. Retorna null si no existe.
  Future<Producto?> obtenerPorSku(String sku);

  /// Busca productos cuyo nombre o SKU contengan [consulta].
  Future<List<Producto>> buscarPorNombreOSku(String consulta);

  /// Obtiene todos los productos de una categoría específica.
  Future<List<Producto>> obtenerPorCategoria(int categoriaId);

  /// Obtiene todos los productos de un proveedor específico.
  Future<List<Producto>> obtenerPorProveedor(int proveedorId);

  /// Obtiene solo los productos activos.
  Future<List<Producto>> obtenerActivos();

  /// Obtiene los productos con stock por debajo del mínimo.
  Future<List<Producto>> obtenerConStockBajo();

  /// Crea un nuevo producto y retorna la entidad creada (con su id asignado).
  Future<Producto> crear(Producto producto);

  /// Actualiza un producto existente y retorna la entidad actualizada.
  Future<Producto> actualizar(Producto producto);

  /// Ajusta el stock de un producto sumando [cantidad] (puede ser negativo para reducir).
  Future<Producto> ajustarStock(int id, double cantidad);

  /// Elimina un producto por su ID.
  Future<void> eliminar(int id);

  /// Verifica si ya existe un producto con ese nombre (ignora mayúsculas).
  /// Usa [excludirId] para excluir el producto actual al editar.
  Future<bool> existeNombre(String nombre, {int? excludirId});

  /// Verifica si ya existe un producto con ese SKU.
  /// Usa [excludirId] para excluir el producto actual al editar.
  Future<bool> existeSku(String sku, {int? excludirId});

  /// Retorna el total de productos activos registrados.
  Future<int> contarActivos();

  /// Retorna el total de productos con stock bajo.
  Future<int> contarConStockBajo();
}