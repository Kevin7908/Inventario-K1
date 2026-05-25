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

  static TablaTecnicoCompanion aCompanion({
    required String nombres,
    String? cedula,
    String? apellidos,
    String? telefono,
    String? email,
    int? especializacionId,
    double? salarioBase,
    required bool activo,
  }) {
    return TablaTecnicoCompanion.insert(
      nombres: nombres,
      cedula: Value(cedula),
      apellidos: Value(apellidos),
      telefono: Value(telefono),
      email: Value(email),
      especializacionId: Value(especializacionId),
      salarioBase: Value(salarioBase),
      activo: Value(activo),
    );
  }
}