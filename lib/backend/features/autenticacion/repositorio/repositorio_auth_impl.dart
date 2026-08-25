import 'dart:isolate';

import 'package:bcrypt/bcrypt.dart';
import 'package:drift/drift.dart';

import '../../../../core/resultado.dart';
import '../../../share/database/app_db.dart';
import '../../../share/dominio/permiso.dart';
import '../../../share/dominio/rol_usuario.dart';
import '../../../share/dominio/sesion_actual.dart';
import '../../bitacora/modelo/entrada_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora_impl.dart';
import '../../persona/modelo/persona.dart';
import '../../persona/repositorio/repositorio_persona.dart';
import '../../persona/repositorio/repositorio_persona_impl.dart';
import '../mapper/usuario_mapper.dart';
import '../modelo/usuario.dart';
import '../resultado/resultados_auth.dart';
import 'repositorio_auth.dart';

/// Coste de bcrypt. Doce rondas son ~250 ms en un equipo de escritorio: caro a
/// propósito, que es de lo que se trata. Por eso [_hashear] y [_verificar] no
/// corren en el isolate principal.
const int _rondasBcrypt = 12;

String _hashearEnIsolate(String password) =>
    BCrypt.hashpw(password, BCrypt.gensalt(logRounds: _rondasBcrypt));

bool _verificarEnIsolate((String, String) par) =>
    BCrypt.checkpw(par.$1, par.$2);

class RepositorioAuthImpl with FirmaDeSesion implements RepositorioAuth {
  /// [sesion] es opcional y por defecto `null`, a diferencia de los demás
  /// repositorios: este se construye **antes** del login —el portal le
  /// pregunta si hay alguna cuenta— y el alta del primer administrador ocurre
  /// cuando todavía no hay nadie que la firme. Todo lo que sí deja rastro
  /// —crear un cajero, activar una cuenta, tocar permisos— pasa después.
  RepositorioAuthImpl(this._db, [this.sesion]);

  final AppDb _db;

  @override
  final SesionActual? sesion;

  late final RepositorioBitacora _bitacora =
      RepositorioBitacoraImpl(_db, sesion);

  /// Anota en la bitácora **si hay quien firme**.
  ///
  /// El primer administrador se crea sin sesión abierta: no hay a quién
  /// atribuirle su propia alta, y esa es toda la excepción. El resto de los
  /// cambios sobre cuentas ocurre con alguien dentro.
  Future<void> _anotar(
    AccionAuditada accion,
    int? id,
    String descripcion, {
    String? detalle,
  }) async {
    if (sesion == null) return;
    await _bitacora.anotar(
      Anotacion(
        entidad: EntidadAuditada.usuario,
        accion: accion,
        entidadId: id,
        descripcion: descripcion,
        detalle: detalle,
      ),
    );
  }

  late final RepositorioPersona _personas = RepositorioPersonaImpl(_db);

  $TablaUsuarioTable get _tabla => _db.tablaUsuario;
  $TablaPersonaTable get _persona => _db.tablaPersona;
  $TablaUsuarioPermisoTable get _permisos => _db.tablaUsuarioPermiso;

  /// `innerJoin` porque `persona_id` es obligatorio: una cuenta sin persona no
  /// existe.
  JoinedSelectStatement<HasResultSet, dynamic> _conPersona() {
    return _db.select(_tabla).join([
      innerJoin(_persona, _persona.id.equalsExp(_tabla.personaId)),
    ]);
  }

  @override
  Future<bool> hayUsuarios() async {
    final conteo = _tabla.id.count();
    final fila = await (_db.selectOnly(_tabla)..addColumns([conteo]))
        .getSingle();
    return (fila.read(conteo) ?? 0) > 0;
  }

  @override
  Future<ResultadoAcceso> autenticar({
    required String identificador,
    required String password,
  }) async {
    final fila = await _filaPorIdentificador(identificador);

    // Sin cuenta no hay hash contra el que comparar, y devolver de inmediato
    // haría que un usuario inexistente respondiera mucho más rápido que uno
    // real: el tiempo de respuesta delataría qué usuarios existen. Se gasta el
    // mismo bcrypt contra un hash de descarte.
    if (fila == null) {
      await _verificar(password, _hashDeDescarte);
      return const CredencialesIncorrectas();
    }

    final cuenta = fila.readTable(_tabla);
    if (!await _verificar(password, cuenta.passwordHash)) {
      return const CredencialesIncorrectas();
    }
    if (!cuenta.estaActivo) return const CuentaDesactivada();

    return AccesoConcedido(UsuarioMapper.filaJoinAModelo(fila, _db));
  }

  @override
  Future<ResultadoCuenta> crearCuenta({
    required String nombre,
    required String usuario,
    required String email,
    required String password,
    required RolUsuario rol,
    String? documento,
  }) async {
    final usuarioNormalizado = usuario.toLowerCase().trim();
    final emailNormalizado = email.toLowerCase().trim();

    // Fuera de la transacción: bcrypt tarda un cuarto de segundo y no tiene
    // por qué tener la base tomada mientras tanto.
    final hash = await _hashear(password);

    try {
      // Persona y cuenta son dos filas: si la segunda choca con un usuario ya
      // tomado, la primera no puede quedar suelta.
      return await _db.transaction<ResultadoCuenta>(() async {
        if (await _uno(_tabla.usuario.equals(usuarioNormalizado)) != null) {
          return const UsuarioEnUso();
        }
        if (emailNormalizado.isNotEmpty &&
            await _uno(_persona.email.equals(emailNormalizado)) != null) {
          return const CorreoEnUso();
        }

        // Si [documento] corresponde a alguien ya registrado —un técnico que
        // ahora tendrá cuenta—, se reutiliza su persona en vez de duplicarla.
        final personaId = await _personas.guardar(
          DatosPersona(
            documento: documento,
            nombres: nombre.trim(),
            email: emailNormalizado.isEmpty ? null : emailNormalizado,
          ),
        );

        final id = await _db.into(_tabla).insert(
              TablaUsuarioCompanion.insert(
                personaId: personaId,
                usuario: usuarioNormalizado,
                passwordHash: hash,
                rol: Value(rol.codigo),
                estaActivo: const Value(true),
              ),
            );

        await _sembrarPermisos(id, rol);
        await _anotar(
          AccionAuditada.creo,
          id,
          '${nombre.trim()} ($usuarioNormalizado)',
          detalle: 'Rol: ${rol.etiqueta}',
        );

        return CuentaCreada((await obtenerPorId(id))!);
      });
    } catch (e) {
      return CuentaNoGuardada(e.toString());
    }
  }

  @override
  Future<Resultado> cambiarPassword({
    required int usuarioId,
    required String passwordNueva,
  }) async {
    if (passwordNueva.length < minimoCaracteresPassword) {
      return const Fallo(
        MotivoFallo.validacion,
        'La contraseña debe tener al menos $minimoCaracteresPassword '
        'caracteres.',
      );
    }

    final hash = await _hashear(passwordNueva);

    final filas = await (_db.update(_tabla)..where((u) => u.id.equals(usuarioId)))
        .write(
      TablaUsuarioCompanion(
        passwordHash: Value(hash),
        actualizadoEn: Value(DateTime.now()),
      ),
    );

    return filas == 0
        ? const Fallo(MotivoFallo.persistencia, 'La cuenta ya no existe.')
        : const Exito();
  }

  @override
  Future<Resultado> cambiarEstado({
    required int adminId,
    required int usuarioId,
    required bool activo,
  }) async {
    return _db.transaction<Resultado>(() async {
      final fallo = await _verificarAdmin(adminId);
      if (fallo != null) return fallo;

      // Desactivar al último administrador activo deja la app sin nadie que
      // pueda volver a activarlo: no hay salida desde dentro.
      if (!activo && await _esUltimoAdminActivo(usuarioId)) {
        return const Fallo(
          MotivoFallo.validacion,
          'Es el único administrador activo. Nombra otro antes de '
          'desactivar esta cuenta.',
        );
      }

      final filas =
          await (_db.update(_tabla)..where((u) => u.id.equals(usuarioId))).write(
        TablaUsuarioCompanion(
          estaActivo: Value(activo),
          actualizadoEn: Value(DateTime.now()),
        ),
      );

      if (filas == 0) {
        return const Fallo(MotivoFallo.persistencia, 'La cuenta ya no existe.');
      }

      await _anotarSobreCuenta(
        usuarioId,
        AccionAuditada.modifico,
        activo ? 'Cuenta activada' : 'Cuenta desactivada',
      );
      return const Exito();
    });
  }

  @override
  Future<Resultado> cambiarRol({
    required int adminId,
    required int usuarioId,
    required RolUsuario rol,
  }) async {
    return _db.transaction<Resultado>(() async {
      final fallo = await _verificarAdmin(adminId);
      if (fallo != null) return fallo;

      if (rol != RolUsuario.admin && await _esUltimoAdminActivo(usuarioId)) {
        return const Fallo(
          MotivoFallo.validacion,
          'Es el único administrador activo. Nombra otro antes de cambiarle '
          'el rol a esta cuenta.',
        );
      }

      final filas =
          await (_db.update(_tabla)..where((u) => u.id.equals(usuarioId))).write(
        TablaUsuarioCompanion(
          rol: Value(rol.codigo),
          actualizadoEn: Value(DateTime.now()),
        ),
      );

      if (filas == 0) {
        return const Fallo(MotivoFallo.persistencia, 'La cuenta ya no existe.');
      }

      // Los permisos vuelven a los del rol nuevo. Conservarlos dejaría a un
      // administrador degradado con la lista de permisos que nunca se le
      // guardó —los suyos salían del rol, no de la tabla— y a un cajero
      // ascendido con una fila que ya no se consulta.
      await _sembrarPermisos(usuarioId, rol);
      await _anotarSobreCuenta(
        usuarioId,
        AccionAuditada.modifico,
        'Rol cambiado a ${rol.etiqueta}',
      );
      return const Exito();
    });
  }

  @override
  Future<Usuario?> obtenerPorIdentificador(String identificador) async {
    final fila = await _filaPorIdentificador(identificador);
    return fila == null ? null : UsuarioMapper.filaJoinAModelo(fila, _db);
  }

  @override
  Future<Usuario?> obtenerPorId(int id) => _uno(_tabla.id.equals(id));

  @override
  Stream<List<Usuario>> observarUsuarios() {
    return (_conPersona()..orderBy([OrderingTerm.asc(_tabla.creadoEn)]))
        .watch()
        .map(
          (filas) =>
              filas.map((f) => UsuarioMapper.filaJoinAModelo(f, _db)).toList(),
        );
  }

  @override
  Future<Set<Permiso>> permisosDe(int usuarioId) async {
    final cuenta = await (_db.select(_tabla)..where((u) => u.id.equals(usuarioId)))
        .getSingleOrNull();
    if (cuenta == null) return const {};

    final rol = RolUsuario.desdeCodigo(cuenta.rol);
    if (rol.administraUsuarios) return Permiso.values.toSet();

    final filas = await (_db.select(_permisos)
          ..where((p) => p.usuarioId.equals(usuarioId)))
        .get();

    return _aPermisos(filas);
  }

  @override
  Stream<Set<Permiso>> observarPermisos(int usuarioId) {
    // `select` sobre las dos tablas: el rol puede cambiar sin que cambie
    // ninguna fila de permisos, y un ascenso a administrador tiene que
    // notarse igual.
    final consulta = _db.select(_tabla).join([
      leftOuterJoin(_permisos, _permisos.usuarioId.equalsExp(_tabla.id)),
    ])
      ..where(_tabla.id.equals(usuarioId));

    return consulta.watch().map((filas) {
      if (filas.isEmpty) return const <Permiso>{};

      final rol = RolUsuario.desdeCodigo(filas.first.readTable(_tabla).rol);
      if (rol.administraUsuarios) return Permiso.values.toSet();

      return _aPermisos(
        filas
            .map((f) => f.readTableOrNull(_permisos))
            .whereType<TablaUsuarioPermisoData>()
            .toList(),
      );
    }).distinct(_mismoConjunto);
  }

  @override
  Future<Resultado> fijarPermisos({
    required int adminId,
    required int usuarioId,
    required Set<Permiso> permisos,
  }) {
    return _db.transaction<Resultado>(() async {
      final fallo = await _verificarAdmin(adminId);
      if (fallo != null) return fallo;

      final cuenta = await (_db.select(_tabla)..where((u) => u.id.equals(usuarioId)))
          .getSingleOrNull();
      if (cuenta == null) {
        return const Fallo(MotivoFallo.persistencia, 'La cuenta ya no existe.');
      }
      if (RolUsuario.desdeCodigo(cuenta.rol).administraUsuarios) {
        return const Fallo(
          MotivoFallo.validacion,
          'Un administrador tiene todos los permisos y no se le pueden quitar. '
          'Cámbiale el rol a Cajero si quieres acotar lo que puede hacer.',
        );
      }

      // `DELETE` + `INSERT` dentro de la transacción: nada apunta a estas
      // filas, así que no hace falta hacer diff (`REGLAS_BD.md` §6).
      await (_db.delete(_permisos)..where((p) => p.usuarioId.equals(usuarioId)))
          .go();
      await _sembrarLista(usuarioId, permisos);

      await (_db.update(_tabla)..where((u) => u.id.equals(usuarioId))).write(
        TablaUsuarioCompanion(actualizadoEn: Value(DateTime.now())),
      );

      await _anotarSobreCuenta(
        usuarioId,
        AccionAuditada.modifico,
        'Permisos actualizados: ${permisos.length} de ${Permiso.values.length}',
      );

      return const Exito();
    });
  }

  // Privados

  /// Anota un cambio sobre una cuenta nombrándola como se lee: «Ana García
  /// (ana)». Se resuelve aquí y no en cada sitio para no repetir el `SELECT`.
  Future<void> _anotarSobreCuenta(
    int usuarioId,
    AccionAuditada accion,
    String detalle,
  ) async {
    if (sesion == null) return;
    final cuenta = await obtenerPorId(usuarioId);
    await _anotar(
      accion,
      usuarioId,
      cuenta == null ? 'Cuenta #$usuarioId' : '${cuenta.nombre} (${cuenta.usuario})',
      detalle: detalle,
    );
  }

  Future<void> _sembrarPermisos(int usuarioId, RolUsuario rol) async {
    await (_db.delete(_permisos)..where((p) => p.usuarioId.equals(usuarioId)))
        .go();
    // A un administrador no se le guarda ninguno: los suyos salen del rol.
    if (rol.administraUsuarios) return;
    await _sembrarLista(usuarioId, rol.permisosPorDefecto);
  }

  Future<void> _sembrarLista(int usuarioId, Set<Permiso> permisos) async {
    if (permisos.isEmpty) return;
    await _db.batch((lote) {
      lote.insertAll(_permisos, [
        for (final permiso in permisos)
          TablaUsuarioPermisoCompanion.insert(
            usuarioId: usuarioId,
            permiso: permiso.codigo,
          ),
      ]);
    });
  }

  /// Un código que ya no está en el catálogo se ignora en vez de convertirse
  /// en otro permiso por accidente.
  static Set<Permiso> _aPermisos(List<TablaUsuarioPermisoData> filas) => {
        for (final fila in filas) ?Permiso.desdeCodigo(fila.permiso),
      };

  /// Drift reemite ante cualquier cambio de `usuarios` o `usuario_permisos`.
  /// Sin esto, editar el nombre de alguien reconstruiría media app.
  static bool _mismoConjunto(Set<Permiso> a, Set<Permiso> b) =>
      a.length == b.length && a.containsAll(b);

  /// Una sola consulta para las dos formas de identificarse: el `OR` lo
  /// resuelve SQLite, en vez de dos viajes desde Dart.
  Future<TypedResult?> _filaPorIdentificador(String identificador) {
    final normalizado = identificador.toLowerCase().trim();
    if (normalizado.isEmpty) return Future.value();

    return (_conPersona()
          ..where(_tabla.usuario.equals(normalizado) |
              _persona.email.equals(normalizado))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<Usuario?> _uno(Expression<bool> condicion) async {
    final fila = await (_conPersona()..where(condicion)).getSingleOrNull();
    return fila == null ? null : UsuarioMapper.filaJoinAModelo(fila, _db);
  }

  /// `null` si [adminId] puede administrar cuentas; el [Fallo] si no.
  ///
  /// Se pregunta por el **permiso** y no por el rol. Parece lo mismo —un
  /// administrador los tiene todos— pero no lo es: la pantalla de permisos
  /// deja darle `USUARIOS_ADMINISTRAR` a un cajero, y si aquí se mirara el rol
  /// ese interruptor no serviría para nada. Un permiso que se puede encender y
  /// no hace nada es peor que no ofrecerlo.
  Future<Fallo?> _verificarAdmin(int adminId) async {
    final admin = await (_db.select(_tabla)..where((u) => u.id.equals(adminId)))
        .getSingleOrNull();

    final autorizado = admin != null &&
        admin.estaActivo &&
        (await permisosDe(adminId)).contains(Permiso.usuariosAdministrar);

    return autorizado
        ? null
        : const Fallo(
            MotivoFallo.validacion,
            'Tu cuenta no tiene permiso para administrar cuentas.',
          );
  }

  Future<bool> _esUltimoAdminActivo(int usuarioId) async {
    final conteo = _tabla.id.count();
    final fila = await (_db.selectOnly(_tabla)
          ..addColumns([conteo])
          ..where(_tabla.rol.equals(RolUsuario.admin.codigo) &
              _tabla.estaActivo.equals(true) &
              _tabla.id.equals(usuarioId).not()))
        .getSingle();

    final otros = fila.read(conteo) ?? 0;
    if (otros > 0) return false;

    // No quedan otros administradores activos; solo cuenta si el afectado lo
    // es: desactivar a un cajero nunca deja la app sin dueño.
    final afectado =
        await (_db.select(_tabla)..where((u) => u.id.equals(usuarioId)))
            .getSingleOrNull();

    return afectado != null &&
        afectado.estaActivo &&
        RolUsuario.desdeCodigo(afectado.rol).administraUsuarios;
  }

  Future<String> _hashear(String password) =>
      Isolate.run(() => _hashearEnIsolate(password));

  Future<bool> _verificar(String password, String hash) =>
      Isolate.run(() => _verificarEnIsolate((password, hash)));
}

/// Hash de una contraseña que nadie usa, para gastar el mismo tiempo cuando el
/// usuario no existe. Generado una vez con doce rondas.
const String _hashDeDescarte =
    r'$2a$12$eal.pGNYp9N.rvnjpPfxAuKRfwRwjwEzYwW.iB/.GRJV7nAoNiORy';
