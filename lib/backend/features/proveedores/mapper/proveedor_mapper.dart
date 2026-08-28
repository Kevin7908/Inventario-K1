import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../modelo/proveedor.dart';

abstract final class ProveedorMapper {
  ProveedorMapper._();

  /// Une las dos filas que forman un proveedor: la del rol y la de la persona.
  static Proveedor filaAModelo(
    TablaProveedorData rol,
    TablaPersonaData persona,
  ) {
    return Proveedor(
      id: rol.id,
      personaId: persona.id,
      nombre: persona.nombres,
      nitCedula: persona.documento,
      contacto: rol.contacto,
      telefono: persona.telefono,
      email: persona.email,
      direccion: persona.direccion,
      ciudad: persona.ciudad,
      notas: rol.notas,
      activo: rol.activo,
      creadoEn: rol.creadoEn,
      actualizadoEn: rol.actualizadoEn,
    );
  }

  static Proveedor filaJoinAModelo(TypedResult fila, AppDb db) => filaAModelo(
        fila.readTable(db.tablaProveedor),
        fila.readTable(db.tablaPersona),
      );

  /// Solo la parte de `proveedores`; la identidad la escribe `PersonaMapper`.
  static TablaProveedorCompanion modeloACompanion(
    Proveedor p, {
    required int personaId,
  }) {
    return TablaProveedorCompanion(
      personaId: Value(personaId),
      contacto: Value(p.contacto),
      notas: Value(p.notas),
      activo: Value(p.activo),
      actualizadoEn: Value(DateTime.now()),
    );
  }
}
