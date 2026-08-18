import 'package:bcrypt/bcrypt.dart';
import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../../persona/modelo/persona.dart';
import '../../persona/repositorio/repositorio_persona.dart';
import '../../persona/repositorio/repositorio_persona_impl.dart';
import '../excepciones/excepciones_auth.dart';
import '../mapper/usuario_mapper.dart';
import '../modelo/usuario.dart';
import 'repositorio_auth.dart';

class RepositorioAuthImpl implements RepositorioAuth {
  RepositorioAuthImpl(this._db);

  final AppDb _db;

  late final RepositorioPersona _personas = RepositorioPersonaImpl(_db);

  $TablaUsuarioTable get _tabla => _db.tablaUsuario;
  $TablaPersonaTable get _persona => _db.tablaPersona;

  /// `innerJoin` porque `persona_id` es obligatorio: una cuenta sin persona no
  /// existe.
  JoinedSelectStatement<HasResultSet, dynamic> _conPersona() {
    return _db.select(_tabla).join([
      innerJoin(_persona, _persona.id.equalsExp(_tabla.personaId)),
    ]);
  }

  @override
  Future<Usuario> registrarUsuario({
    required String nombre,
    required String usuario,
    required String email,
    required String passwordPlano,
    bool esAdmin = false,
    String? documento,
  }) {
    final usuarioNormalizado = usuario.toLowerCase().trim();
    final emailNormalizado = email.toLowerCase().trim();

    // Persona y cuenta son dos filas: si la segunda choca con un usuario ya
    // tomado, la primera no puede quedar suelta.
    return _db.transaction(() async {
      if (await obtenerPorUsuario(usuarioNormalizado) != null) {
        throw const UsuarioYaExisteException();
      }
      if (await obtenerPorEmail(emailNormalizado) != null) {
        throw const UsuarioYaExisteException('El correo ya está registrado.');
      }

      final hash = BCrypt.hashpw(passwordPlano, BCrypt.gensalt(logRounds: 12));

      // Si [documento] corresponde a alguien ya registrado —un técnico que
      // ahora tendrá cuenta—, se reutiliza su persona en vez de duplicarla.
      final personaId = await _personas.guardar(
        DatosPersona(
          documento: documento,
          nombres: nombre.trim(),
          email: emailNormalizado,
        ),
      );

      final id = await _db.into(_tabla).insert(
            TablaUsuarioCompanion.insert(
              personaId: personaId,
              usuario: usuarioNormalizado,
              passwordHash: hash,
              esAdmin: Value(esAdmin),
              estaActivo: const Value(true),
            ),
          );

      return (await obtenerPorId(id))!;
    });
  }

  @override
  Future<Usuario> verificarCredenciales({
    required String usuario,
    required String passwordPlano,
  }) async {
    final encontrado = await obtenerPorUsuario(usuario);
    if (encontrado == null) throw const CredencialesInvalidasException();

    if (!BCrypt.checkpw(passwordPlano, encontrado.passwordHash)) {
      throw const CredencialesInvalidasException();
    }
    if (!encontrado.estaActivo) throw const AccesoDesactivadoException();

    return encontrado;
  }

  @override
  Future<void> cambiarEstadoActivo({
    required int adminId,
    required int usuarioId,
    required bool nuevoEstado,
  }) async {
    final admin = await (_db.select(_tabla)..where((u) => u.id.equals(adminId)))
        .getSingleOrNull();

    if (admin == null || !admin.esAdmin || !admin.estaActivo) {
      throw const SinPermisosException();
    }

    await (_db.update(_tabla)..where((u) => u.id.equals(usuarioId)))
        .write(TablaUsuarioCompanion(estaActivo: Value(nuevoEstado)));
  }

  @override
  Future<Usuario?> obtenerPorUsuario(String usuario) =>
      _uno(_tabla.usuario.equals(usuario.toLowerCase().trim()));

  @override
  Future<Usuario?> obtenerPorEmail(String email) =>
      _uno(_persona.email.equals(email.toLowerCase().trim()));

  @override
  Future<Usuario?> obtenerPorId(int id) => _uno(_tabla.id.equals(id));

  @override
  Stream<List<Usuario>> observarTodosUsuarios() {
    return (_conPersona()..orderBy([OrderingTerm.asc(_tabla.creadoEn)]))
        .watch()
        .map(
          (filas) =>
              filas.map((f) => UsuarioMapper.filaJoinAModelo(f, _db)).toList(),
        );
  }

  Future<Usuario?> _uno(Expression<bool> condicion) async {
    final fila = await (_conPersona()..where(condicion)).getSingleOrNull();
    return fila == null ? null : UsuarioMapper.filaJoinAModelo(fila, _db);
  }
}
