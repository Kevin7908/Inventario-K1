import 'package:inventario_k1/backend/features/autenticacion/modelo/usuario.dart';
import 'package:inventario_k1/backend/features/autenticacion/repositorio/repositorio_auth.dart';
import 'package:inventario_k1/backend/features/autenticacion/resultado/resultados_auth.dart';
import 'package:inventario_k1/backend/share/dominio/permiso.dart';
import 'package:inventario_k1/backend/share/dominio/rol_usuario.dart';
import 'package:inventario_k1/core/resultado.dart';

/// Una cuenta cualquiera, para los tests que miran pantallas.
Usuario usuarioDePrueba({
  int id = 1,
  String nombre = 'Juan García',
  String usuario = 'juan',
  String email = 'juan@taller.com',
  RolUsuario rol = RolUsuario.admin,
  bool activo = true,
}) =>
    Usuario(
      id: id,
      personaId: id,
      nombre: nombre,
      usuario: usuario,
      email: email,
      rol: rol,
      estaActivo: activo,
      creadoEn: DateTime(2026, 8, 1),
    );

/// Un repositorio de cuentas de mentira: responde lo que le digan sin tocar
/// SQLite.
///
/// Hace falta porque los tests que lo usan miran la vista, no la base. Lo del
/// backend ya está cubierto en `repositorio_auth_test.dart` contra Drift en
/// memoria, con las FK activas.
class RepositorioAuthFalso implements RepositorioAuth {
  RepositorioAuthFalso({
    this.hay = true,
    this.acceso = const CredencialesIncorrectas(),
    this.porIdentificador,
    this.lista = const [],
    this.permisosPorCuenta = const {},
    Set<Permiso>? permisos,
  }) : permisos = permisos ?? Permiso.values.toSet();

  bool hay;
  ResultadoAcceso acceso;
  Usuario? porIdentificador;

  /// Lo que devuelve `observarUsuarios`.
  List<Usuario> lista;

  /// Lo que devuelve `observarPermisos` para la cuenta que no esté en
  /// [permisosPorCuenta]. Por defecto, todos.
  Set<Permiso> permisos;

  /// Permisos de una cuenta concreta. Hace falta en cuanto un test mira la
  /// ficha de un cajero: quien la abre es un administrador, y si los dos
  /// leyeran el mismo conjunto, acotar al cajero dejaría al admin sin
  /// `usuariosAdministrar` y la pantalla se cerraría sola.
  Map<int, Set<Permiso>> permisosPorCuenta;

  String? identificadorPedido;

  /// Lo último que recibió `fijarPermisos`.
  Set<Permiso>? permisosGuardados;

  @override
  Future<bool> hayUsuarios() async => hay;

  @override
  Future<ResultadoAcceso> autenticar({
    required String identificador,
    required String password,
  }) async {
    identificadorPedido = identificador;
    return acceso;
  }

  @override
  Future<Usuario?> obtenerPorIdentificador(String identificador) async {
    identificadorPedido = identificador;
    return porIdentificador;
  }

  @override
  Future<ResultadoCuenta> crearCuenta({
    required String nombre,
    required String usuario,
    required String email,
    required String password,
    required RolUsuario rol,
    String? documento,
  }) async =>
      CuentaCreada(
        usuarioDePrueba(usuario: usuario, email: email, rol: rol),
      );

  @override
  Future<Resultado> cambiarPassword({
    required int usuarioId,
    required String passwordNueva,
  }) async =>
      const Exito();

  @override
  Future<Resultado> cambiarEstado({
    required int adminId,
    required int usuarioId,
    required bool activo,
  }) async =>
      const Exito();

  @override
  Future<Resultado> cambiarRol({
    required int adminId,
    required int usuarioId,
    required RolUsuario rol,
  }) async =>
      const Exito();

  @override
  Future<Usuario?> obtenerPorId(int id) async => porIdentificador;

  @override
  Stream<List<Usuario>> observarUsuarios() => Stream.value(lista);

  @override
  Future<Set<Permiso>> permisosDe(int usuarioId) async =>
      permisosPorCuenta[usuarioId] ?? permisos;

  @override
  Stream<Set<Permiso>> observarPermisos(int usuarioId) =>
      Stream.value(permisosPorCuenta[usuarioId] ?? permisos);

  @override
  Future<Resultado> fijarPermisos({
    required int adminId,
    required int usuarioId,
    required Set<Permiso> permisos,
  }) async {
    permisosGuardados = permisos;
    return const Exito();
  }
}
