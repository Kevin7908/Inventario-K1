import 'package:bcrypt/bcrypt.dart';
import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/autenticacion/mapper/usuario_mapper.dart';

import '../../../share/database/app_db.dart';
import '../excepciones/excepciones_auth.dart';
import '../modelo/usuario.dart';
import '../repositorio/repositorio_auth.dart';

class RepositorioAuthImpl implements RepositorioAuth {
  final AppDb _db;
  RepositorioAuthImpl(this._db);

  @override
  Future<Usuario> registrarUsuario({
    required String nombre,
    required String usuario,
    required String email,
    required String passwordPlano,
    bool esAdmin = false,
  }) async {
    // Verificar unicidad de usuario Y email
    final porUsuario = await (_db.select(_db.tablaUsuario)
          ..where((u) => u.usuario.equals(usuario.toLowerCase().trim())))
        .getSingleOrNull();

    if (porUsuario != null) throw const UsuarioYaExisteException();

    final porEmail = await (_db.select(_db.tablaUsuario)
          ..where((u) => u.email.equals(email.toLowerCase().trim())))
        .getSingleOrNull();

    if (porEmail != null) throw const UsuarioYaExisteException('El correo ya está registrado.');

    final hash = BCrypt.hashpw(passwordPlano, BCrypt.gensalt(logRounds: 12));

    final id = await _db.into(_db.tablaUsuario).insert(
          TablaUsuarioCompanion.insert(
            nombre: nombre.trim(),
            usuario: usuario.toLowerCase().trim(),
            email: email.toLowerCase().trim(),
            passwordHash: hash,
            esAdmin: Value(esAdmin),
            estaActivo: const Value(true),
          ),
        );

    return Usuario(
      id: id,
      nombre: nombre.trim(),
      usuario: usuario.toLowerCase().trim(),
      email: email.toLowerCase().trim(),
      passwordHash: hash,
      esAdmin: esAdmin,
      estaActivo: true,
      creadoEn: DateTime.now(),
    );
  }

  @override
  Future<Usuario> verificarCredenciales({
    required String usuario,
    required String passwordPlano,
  }) async {
    // Buscar por nombre de usuario
    final fila = await (_db.select(_db.tablaUsuario)
          ..where((u) => u.usuario.equals(usuario.toLowerCase().trim())))
        .getSingleOrNull();

    if (fila == null) throw const CredencialesInvalidasException();

    final esValida = BCrypt.checkpw(passwordPlano, fila.passwordHash);
    if (!esValida) throw const CredencialesInvalidasException();

    if (!fila.estaActivo) throw const AccesoDesactivadoException();

    return UsuarioMapper.filaAModelo(fila);
  }

  @override
  Future<void> cambiarEstadoActivo({
    required int adminId,
    required int usuarioId,
    required bool nuevoEstado,
  }) async {
    final admin = await (_db.select(_db.tablaUsuario)
          ..where((u) => u.id.equals(adminId)))
        .getSingleOrNull();

    if (admin == null || !admin.esAdmin || !admin.estaActivo) {
      throw const SinPermisosException();
    }

    await (_db.update(_db.tablaUsuario)
          ..where((u) => u.id.equals(usuarioId)))
        .write(TablaUsuarioCompanion(estaActivo: Value(nuevoEstado)));
  }

  @override
  Future<Usuario?> obtenerPorUsuario(String usuario) async {
    final fila = await (_db.select(_db.tablaUsuario)
          ..where((u) => u.usuario.equals(usuario.toLowerCase().trim())))
        .getSingleOrNull();
    return fila != null ? UsuarioMapper.filaAModelo(fila) : null;
  }

  @override
  Future<Usuario?> obtenerPorEmail(String email) async {
    final fila = await (_db.select(_db.tablaUsuario)
          ..where((u) => u.email.equals(email.toLowerCase().trim())))
        .getSingleOrNull();
    return fila != null ? UsuarioMapper.filaAModelo(fila) : null;
  }

  @override
  Future<Usuario?> obtenerPorId(int id) async {
    final fila = await (_db.select(_db.tablaUsuario)
          ..where((u) => u.id.equals(id)))
        .getSingleOrNull();
    return fila != null ? UsuarioMapper.filaAModelo(fila) : null;
  }

  @override
  Stream<List<Usuario>> observarTodosUsuarios() {
    return (_db.select(_db.tablaUsuario)
          ..orderBy([(u) => OrderingTerm.asc(u.creadoEn)]))
        .watch()
        .map((filas) => filas.map(UsuarioMapper.filaAModelo).toList());
  }
}