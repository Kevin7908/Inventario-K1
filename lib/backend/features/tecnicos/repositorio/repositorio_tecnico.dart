import '../modelo/tecnico.dart';

abstract interface class RepositorioTecnico {
  
  Stream<List<Tecnico>> observarTodos();

  Future<bool> existeCedula(String cedula, {int? excluirId});

  Future<Tecnico> insertar({
    required String nombres,
    String? cedula,
    String? apellidos,
    String? telefono,
    String? email,
    int? especializacionId,
    double? salarioBase,
    required bool activo,
  });

  Future<Tecnico> actualizar({
    required int id,
    required String nombres,
    String? cedula,
    String? apellidos,
    String? telefono,
    String? email,
    int? especializacionId,
    double? salarioBase,
    required bool activo,
  });

  Future<void> eliminar(int id);
}