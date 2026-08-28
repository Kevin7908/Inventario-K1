import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/permiso.dart';
import 'package:inventario_k1/backend/share/dominio/rol_usuario.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';

/// La cuenta que firma lo que escriben los tests.
///
/// Hace falta porque `usuario_id` es `NOT NULL` con FK en ocho tablas: sin una
/// cuenta real en la base, cualquier venta o movimiento de inventario rebota.
///
/// **Inserta la fila a mano en vez de pasar por `RepositorioAuth`**: crear una
/// cuenta de verdad cuesta un bcrypt de doce rondas —un cuarto de segundo— y
/// se pagaría en cada `setUp` de la suite. Lo que estos tests prueban es el
/// repositorio de turno, no el alta de usuarios; eso tiene el suyo en
/// `repositorio_auth_test.dart`.
///
/// Por defecto la sesión trae **todos** los permisos, que es lo que quiere un
/// test que no está probando permisos. Para probar una compuerta, se pasa el
/// conjunto que corresponda:
///
/// ```dart
/// final sinBorrar = await sesionDePrueba(db, permisos: {Permiso.productosVer});
/// ```
Future<SesionActual> sesionDePrueba(
  AppDb db, {
  Set<Permiso>? permisos,
  RolUsuario rol = RolUsuario.admin,
  String usuario = 'tester',
}) async {
  final personaId = await db.into(db.tablaPersona).insert(
        TablaPersonaCompanion.insert(nombres: 'Usuario de prueba'),
      );

  final usuarioId = await db.into(db.tablaUsuario).insert(
        TablaUsuarioCompanion.insert(
          personaId: personaId,
          usuario: usuario,
          passwordHash: 'hash-de-prueba',
          rol: Value(rol.codigo),
        ),
      );

  return SesionActual(
    usuarioId: usuarioId,
    rol: rol,
    permisos: permisos ?? Permiso.values.toSet(),
  );
}
