import '../modelo/usuario.dart';

abstract class RepositorioAuth {
  /// Registra usuario. Lanza [UsuarioYaExisteException] si el usuario o email
  /// ya están en uso.
  Future<Usuario> registrarUsuario({
    required String nombre,
    required String usuario, // ← nuevo
    required String email,
    required String passwordPlano,
    bool esAdmin = false,
  });

  /// Login con usuario (no email) + contraseña.
  Future<Usuario> verificarCredenciales({
    required String usuario, // ← cambió de email a usuario
    required String passwordPlano,
  });

  Future<void> cambiarEstadoActivo({
    required int adminId,
    required int usuarioId,
    required bool nuevoEstado,
  });

  Future<Usuario?> obtenerPorUsuario(String usuario); // ← nuevo
  Future<Usuario?> obtenerPorEmail(String email);
  Future<Usuario?> obtenerPorId(int id);
  Stream<List<Usuario>> observarTodosUsuarios();
}