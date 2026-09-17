import '../../../../core/resultado.dart';
import '../modelo/compatibilidad.dart';

/// A qué motos le sirve cada repuesto.
///
/// Vive aparte del repositorio de productos y no dentro de él porque son dos
/// preguntas distintas con dos ciclos de vida distintos: el catálogo se
/// consulta paginado en cada tecla del mostrador, y esto se abre solo al ver
/// la ficha de un producto. Meterlo en `RepositorioProducto` obligaría a que
/// toda consulta de catálogo cargara con el JOIN de las compatibilidades.
abstract interface class RepositorioCompatibilidades {
  /// Lo que declara un producto, con marca y modelo ya resueltos.
  Stream<List<Compatibilidad>> observarDeProducto(int productoId);

  Future<List<Compatibilidad>> obtenerDeProducto(int productoId);

  // Preguntar «qué repuestos le sirven a esta moto» **no** vive aquí: es un
  // filtro más de `FiltroProductos` —`compatibleConMarcaId` /
  // `compatibleConModeloId`—, para que el `WHERE`, el `COUNT` y el `LIMIT`
  // salgan de la misma consulta paginada. Traer aquí el conjunto de ids para
  // descartar filas después rompería el total de la paginación
  // (`REGLAS_BD.md` §5).

  /// Declara que el producto le sirve a **toda** una marca.
  Future<Resultado> agregarMarca({
    required int productoId,
    required int marcaId,
  });

  /// Declara que el producto le sirve a **un** modelo.
  Future<Resultado> agregarModelo({
    required int productoId,
    required int modeloId,
  });

  Future<Resultado> eliminar(int compatibilidadId);
}
