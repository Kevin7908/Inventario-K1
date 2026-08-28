import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../modelo/entrada_bitacora.dart';

abstract final class BitacoraMapper {
  BitacoraMapper._();

  /// Une las tres filas que forman un renglón legible: el hecho, la cuenta y
  /// la persona detrás de esa cuenta.
  static EntradaBitacora filaAModelo(TypedResult fila, AppDb db) {
    final hecho = fila.readTable(db.tablaBitacora);
    final cuenta = fila.readTable(db.tablaUsuario);
    final persona = fila.readTable(db.tablaPersona);

    return EntradaBitacora(
      id: hecho.id,
      usuarioId: hecho.usuarioId,
      nombreUsuario: persona.nombres,
      usuario: cuenta.usuario,
      entidad: EntidadAuditada.desdeCodigo(hecho.entidad),
      entidadId: hecho.entidadId,
      accion: AccionAuditada.desdeCodigo(hecho.accion),
      descripcion: hecho.descripcion,
      detalle: hecho.detalle,
      creadoEn: hecho.creadoEn,
    );
  }
}
