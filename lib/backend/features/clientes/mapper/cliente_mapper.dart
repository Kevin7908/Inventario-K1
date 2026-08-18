import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../../persona/modelo/persona.dart';
import '../modelo/cliente.dart';

abstract final class ClienteMapper {
  ClienteMapper._();

  /// Une las dos filas que hoy forman un cliente: la del rol y la de la
  /// persona. Nunca se lee una sin la otra —el `JOIN` es interno, no opcional.
  static Cliente filaAModelo(
    TablaClienteData rol,
    TablaPersonaData persona,
  ) {
    return Cliente(
      id: rol.id,
      personaId: persona.id,
      tipoDocumento: TipoDocumento.desdeCodigo(persona.tipoDocumento),
      documento: persona.documento,
      nombres: persona.nombres,
      apellidos: persona.apellidos,
      telefono: persona.telefono,
      email: persona.email,
      direccion: persona.direccion,
      ciudad: persona.ciudad,
      fechaNacimiento: rol.fechaNacimiento,
      notas: rol.notas,
      activo: rol.activo,
      creadoEn: rol.creadoEn,
      actualizadoEn: rol.actualizadoEn,
    );
  }

  static Cliente filaJoinAModelo(TypedResult fila, AppDb db) => filaAModelo(
        fila.readTable(db.tablaCliente),
        fila.readTable(db.tablaPersona),
      );

  /// Solo la parte de `clientes`. La identidad la escribe [PersonaMapper] y su
  /// id llega aquí como [personaId].
  static TablaClienteCompanion modeloACompanion(
    Cliente modelo, {
    required int personaId,
  }) {
    return TablaClienteCompanion(
      personaId: Value(personaId),
      fechaNacimiento: Value(modelo.fechaNacimiento),
      notas: Value(modelo.notas),
      activo: Value(modelo.activo),
      actualizadoEn: Value(DateTime.now()),
    );
  }
}
