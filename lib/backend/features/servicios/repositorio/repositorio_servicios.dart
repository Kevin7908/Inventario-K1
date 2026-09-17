import '../../../../core/resultado.dart';
import '../modelo/servicio.dart';

/// El catálogo de servicios del taller.
///
/// Las escrituras devuelven `Resultado` y no la entidad ni `void`
/// (`REGLAS_BD.md` §8): el nombre repetido y el permiso que falta son fallos
/// esperables, y decidir el texto es de la vista. Lo único que escapa de aquí
/// es un fallo real de SQLite, ya envuelto en un [Fallo].
abstract interface class RepositorioServicios {

  Stream<List<Servicio>> observarTodos();

  Future<List<Servicio>> obtenerTodos();

  /// Snapshot puntual para validar mientras se teclea. La garantía de verdad
  /// es el `UNIQUE` de la tabla, que este método no sustituye.
  Future<bool> existeNombre(String nombre, {int? ignorarId});


  Future<Resultado> agregar({
    required String nombre,
    String? descripcion,
    int precioSugerido = 0,
    bool activo,
  });

  Future<Resultado> actualizar({
    required int id,
    required String nombre,
    String? descripcion,
    int precioSugerido = 0,
    required bool activo,
  });

  Future<Resultado> eliminar(int id);

  // Cambia solo el campo activo sin tocar el resto.
  Future<Resultado> alternarActivo(int id, {required bool activo});
}
