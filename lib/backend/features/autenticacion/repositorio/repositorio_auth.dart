import '../../../../core/resultado.dart';
import '../../../share/dominio/permiso.dart';
import '../../../share/dominio/rol_usuario.dart';
import '../modelo/usuario.dart';
import '../resultado/resultados_auth.dart';

/// Mínimo de caracteres de una contraseña.
///
/// Lo aplica el repositorio, que es donde manda, y lo lee la vista para poder
/// avisar antes de mandar nada. Un solo número: si la regla cambia, cambia en
/// los dos sitios a la vez.
const int minimoCaracteresPassword = 8;

/// Las cuentas de acceso a la app.
///
/// Ningún método lanza excepciones de negocio: todos devuelven un tipo sellado
/// (`REGLAS_BD.md` §8). Lo único que puede escapar de aquí es un fallo real de
/// SQLite, y eso ya viene envuelto en un [Fallo].
abstract class RepositorioAuth {
  /// ¿Hay alguna cuenta creada?
  ///
  /// Es lo que decide si la app arranca en el login o en «crear la cuenta del
  /// administrador»: una base recién instalada no tiene con qué dejar entrar a
  /// nadie.
  Future<bool> hayUsuarios();

  /// Entra con **usuario o correo** indistintamente, más la contraseña.
  ///
  /// El taller no tiene por qué recordar cuál de los dos registró: se busca
  /// por los dos y gana el que aparezca.
  Future<ResultadoAcceso> autenticar({
    required String identificador,
    required String password,
  });

  /// Crea la cuenta y, si hace falta, la persona detrás.
  ///
  /// Si [documento] corresponde a alguien que ya está en `personas` —un
  /// técnico que ahora va a tener cuenta—, se reutiliza esa persona en vez de
  /// duplicarla.
  Future<ResultadoCuenta> crearCuenta({
    required String nombre,
    required String usuario,
    required String email,
    required String password,
    required RolUsuario rol,
    String? documento,
  });

  /// Cambia la contraseña de una cuenta. La usa el flujo de recuperación una
  /// vez el código del correo quedó validado.
  Future<Resultado> cambiarPassword({
    required int usuarioId,
    required String passwordNueva,
  });

  /// Activa o desactiva una cuenta. Solo un administrador activo puede.
  Future<Resultado> cambiarEstado({
    required int adminId,
    required int usuarioId,
    required bool activo,
  });

  /// Cambia el rol de una cuenta. Solo un administrador activo puede.
  Future<Resultado> cambiarRol({
    required int adminId,
    required int usuarioId,
    required RolUsuario rol,
  });

  /// Busca por usuario **o** correo, como hace el login. Devuelve `null` si no
  /// hay ninguna cuenta con ese dato.
  Future<Usuario?> obtenerPorIdentificador(String identificador);

  Future<Usuario?> obtenerPorId(int id);

  /// Todas las cuentas, para la pantalla de administración.
  Stream<List<Usuario>> observarUsuarios();

  /// Lo que esta cuenta puede hacer, ya resuelto.
  ///
  /// Para un administrador son **todos** y no se consulta `usuario_permisos`:
  /// el rol manda sobre la tabla. Para los demás, lo que diga su fila.
  Future<Set<Permiso>> permisosDe(int usuarioId);

  /// Los permisos de una cuenta, en vivo. Lo observa la sesión abierta para
  /// que quitarle un permiso a alguien se note sin obligarlo a volver a
  /// entrar.
  Stream<Set<Permiso>> observarPermisos(int usuarioId);

  /// Reemplaza **todos** los permisos de una cuenta por los que se pasan.
  ///
  /// Es un reemplazo y no un alta/baja porque la pantalla envía el estado
  /// completo de los interruptores: comparar cuál cambió aquí sería adivinar
  /// lo que la vista ya sabe.
  ///
  /// Sobre una cuenta de administrador falla: sus permisos no se editan.
  Future<Resultado> fijarPermisos({
    required int adminId,
    required int usuarioId,
    required Set<Permiso> permisos,
  });
}
