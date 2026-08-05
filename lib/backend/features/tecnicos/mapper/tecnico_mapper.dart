import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../modelo/tecnico.dart';

abstract final class TecnicoMapper {
  TecnicoMapper._();

  static Tecnico desdeFila(TablaTecnicoData fila) {
    return Tecnico(
      id: fila.id,
      cedula: fila.cedula,
      nombres: fila.nombres,
      apellidos: fila.apellidos,
      telefono: fila.telefono,
      email: fila.email,
      especializacionId: fila.especializacionId,
      salarioBase: fila.salarioBase,
      activo: fila.activo,
      creadoEn: fila.creadoEn,
    );
  }

  static TablaTecnicoCompanion modeloACompanion(Tecnico t) {
    return TablaTecnicoCompanion(
      cedula: Value(t.cedula),
      nombres: Value(t.nombres),
      apellidos: Value(t.apellidos),
      telefono: Value(t.telefono),
      email: Value(t.email),
      especializacionId: Value(t.especializacionId),
      salarioBase: Value(t.salarioBase),
      activo: Value(t.activo),
      creadoEn: Value(t.creadoEn),
    );
  }
}
