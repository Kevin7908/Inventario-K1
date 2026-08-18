import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../modelo/usuario.dart';

abstract final class UsuarioMapper {
  UsuarioMapper._();

  /// Une las dos filas que forman una cuenta: la del rol y la de la persona.
  static Usuario filaAModelo(TablaUsuarioData rol, TablaPersonaData persona) {
    return Usuario(
      id: rol.id,
      personaId: persona.id,
      nombre: persona.nombres,
      // `personas.email` es nullable; una cuenta sin correo se lee como cadena
      // vacía para no obligar a todo el módulo de login a manejar un `null`.
      email: persona.email ?? '',
      usuario: rol.usuario,
      passwordHash: rol.passwordHash,
      esAdmin: rol.esAdmin,
      estaActivo: rol.estaActivo,
      creadoEn: rol.creadoEn,
    );
  }

  static Usuario filaJoinAModelo(TypedResult fila, AppDb db) => filaAModelo(
        fila.readTable(db.tablaUsuario),
        fila.readTable(db.tablaPersona),
      );
}
