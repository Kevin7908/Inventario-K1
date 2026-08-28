import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../../persona/modelo/persona.dart';
import '../modelo/tecnico.dart';

abstract final class TecnicoMapper {
  TecnicoMapper._();

  static Tecnico desdeFila(TablaTecnicoData rol, TablaPersonaData persona) {
    return Tecnico(
      id: rol.id,
      personaId: persona.id,
      tipoDocumento: TipoDocumento.desdeCodigo(persona.tipoDocumento),
      documento: persona.documento,
      nombres: persona.nombres,
      apellidos: persona.apellidos,
      telefono: persona.telefono,
      email: persona.email,
      especializacionId: rol.especializacionId,
      salarioBase: rol.salarioBase,
      activo: rol.activo,
      creadoEn: rol.creadoEn,
    );
  }

  static Tecnico desdeJoin(TypedResult fila, AppDb db) => desdeFila(
        fila.readTable(db.tablaTecnico),
        fila.readTable(db.tablaPersona),
      );

  /// Solo la parte de `tecnicos`; la identidad la escribe `PersonaMapper`.
  static TablaTecnicoCompanion modeloACompanion(
    Tecnico t, {
    required int personaId,
  }) {
    return TablaTecnicoCompanion(
      personaId: Value(personaId),
      especializacionId: Value(t.especializacionId),
      salarioBase: Value(t.salarioBase),
      activo: Value(t.activo),
      creadoEn: Value(t.creadoEn),
      actualizadoEn: Value(DateTime.now()),
    );
  }
}
