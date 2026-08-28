import '../modelo/producto.dart';

/// Una página de resultados junto al total de coincidencias.
///
/// [total] cuenta **todas** las filas que cumplen el filtro, no las de la
/// página: es lo que necesita el paginador para saber cuántas páginas hay.
class PaginaProductos {
  const PaginaProductos({required this.items, required this.total});

  final List<Producto> items;
  final int total;

  static const vacia = PaginaProductos(items: [], total: 0);
}

/// Criterios de filtrado que se aplican **en SQL**, no en memoria.
class FiltroProductos {
  const FiltroProductos({
    this.busqueda = '',
    this.categoriaId,
    this.soloStockBajo = false,
    this.soloSinStock = false,
    this.soloEnStock = false,
    this.soloActivos = false,
  });

  /// Coincide contra nombre, SKU o nombre de categoría.
  final String busqueda;
  final int? categoriaId;
  final bool soloStockBajo;
  final bool soloSinStock;
  final bool soloEnStock;

  /// Deja fuera lo dado de baja. Lo piden las pantallas que **venden** —punto
  /// de venta y cotizaciones—, no el catálogo: en Productos, un producto
  /// inactivo tiene que verse para poder reactivarlo.
  final bool soloActivos;
}

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

  /// El SKU que le tocaría al siguiente producto de [categoriaId], **sin
  /// consumirlo**.
  ///
  /// Es para enseñarlo en el formulario mientras se escribe. El definitivo lo
  /// asigna [crear] dentro de su transacción: abrir el formulario y
  /// arrepentirse no puede quemar un código.
  Future<String> previsualizarSku(int? categoriaId);

  /// Retorna el total de productos activos registrados.
  Future<int> contarActivos();

  /// Retorna el total de productos con stock bajo.
  Future<int> contarConStockBajo();

  // Paginación — el filtrado y el conteo ocurren en la base de datos.

  /// Observa una página de productos que cumplen [filtro].
  ///
  /// [pagina] es de base cero. Re-emite cuando cambian los datos, igual que
  /// [observarTodos], pero trayendo solo [tamano] filas en vez del catálogo
  /// completo.
  Stream<PaginaProductos> observarPagina({
    required FiltroProductos filtro,
    required int pagina,
    required int tamano,
  });

  /// Observa cuántos productos tiene cada categoría, indexado por su id.
  ///
  /// Se resuelve con un `GROUP BY`, no cargando los productos en memoria.
  Stream<Map<int, int>> observarConteoPorCategoria();

  /// Observa cuántos productos surte cada proveedor, indexado por su id.
  ///
  /// Igual que [observarConteoPorCategoria], sale de un `GROUP BY`: es el
  /// "N productos" que muestra cada tarjeta de proveedor.
  Stream<Map<int, int>> observarConteoPorProveedor();

  /// Observa cuántos productos hay en cada estado de stock.
  ///
  /// Los tres estados son excluyentes y suman `total`, para que los chips de
  /// filtro puedan mostrar su conteo sin recorrer el catálogo:
  /// - `enStock`: `stockActual > stockMinimo`
  /// - `stockBajo`: `0 < stockActual <= stockMinimo`
  /// - `sinStock`: `stockActual <= 0`
  ///
  /// De [filtro] solo se aplican la búsqueda y la categoría: los tramos de
  /// stock son justamente lo que se está contando. Sin filtro cuenta todo el
  /// catálogo, que es lo que necesita el encabezado de la pantalla.
  Stream<({int total, int enStock, int stockBajo, int sinStock})>
      observarResumen({FiltroProductos filtro});
}