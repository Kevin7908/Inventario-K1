import '../modelo/servicio.dart';

abstract interface class RepositorioServicios {

  Stream<List<Servicio>> observarTodos();

  Future<List<Servicio>> obtenerTodos();

  Future<bool> existeNombre(String nombre, {int? ignorarId});


  Future<Servicio> agregar({
    required String nombre,
    String? descripcion,
    bool activo,
  });

  Future<Servicio> actualizar({
    required int id,
    required String nombre,
    String? descripcion,
    required bool activo,
  });

  Future<void> eliminar(int id);

  // Cambia solo el campo activo sin tocar el resto.
  Future<void> alternarActivo(int id, {required bool activo});
}