import '../modelo/usuario.dart';

abstract class RepositorioAuth {
  /// Registra usuario. Lanza [UsuarioYaExisteException] si el usuario o email
  /// ya están en uso.
  ///
  /// Si [documento] corresponde a alguien que ya está en `personas` —un
  /// técnico que ahora va a tener cuenta—, se reutiliza esa persona en vez de
  /// duplicarla.
  Future<Usuario> registrarUsuario({
    required String nombre,
    required String usuario,
    required String email,
    required String passwordPlano,
    bool esAdmin = false,
    String? documento,
  });

  /// Login con usuario (no email) + contraseña.
  Future<Usuario> verificarCredenciales({
    required String usuario,
    required String passwordPlano,
  });

  Future<void> cambiarEstadoActivo({
    required int adminId,
    required int usuarioId,
    required bool nuevoEstado,
  });

  Future<Usuario?> obtenerPorUsuario(String usuario);
  Future<Usuario?> obtenerPorEmail(String email);
  Future<Usuario?> obtenerPorId(int id);
  Stream<List<Usuario>> observarTodosUsuarios();
}