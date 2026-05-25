import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../modelo/cliente.dart';

class ClienteMapper {
  ClienteMapper._();

  static Cliente filaAModelo(TablaClienteData fila) {
    return Cliente(
      id: fila.id,
      cedula: fila.cedula,
      nombres: fila.nombres,
      apellidos: fila.apellidos,
      telefono: fila.telefono,
      email: fila.email,
      direccion: fila.direccion,
      ciudad: fila.ciudad,
      fechaNacimiento: fila.fechaNacimiento,
      notas: fila.notas,
      activo: fila.activo == 1,
      creadoEn: fila.creadoEn,
      actualizadoEn: fila.actualizadoEn,
    );
  }

  static TablaClienteCompanion modeloACompanion(Cliente modelo) {
    return TablaClienteCompanion.insert(
      cedula: Value(modelo.cedula),
      nombres: modelo.nombres,
      apellidos: Value(modelo.apellidos),
      telefono: Value(modelo.telefono),
      email: Value(modelo.email),
      direccion: Value(modelo.direccion),
      ciudad: Value(modelo.ciudad),
      fechaNacimiento: Value(modelo.fechaNacimiento),
      notas: Value(modelo.notas),
      activo: Value(modelo.activo ? 1 : 0),
      actualizadoEn: Value(DateTime.now()),
    );
  }
}