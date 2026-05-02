import 'package:drift/drift.dart';
import '../../../share/database/app_db.dart';
import '../modelo/proveedor.dart';

class ProveedorMapper {
  // Convierte una fila de Drift al modelo de dominio
  static Proveedor filaAModelo(TablaProveedorData fila) {
    return Proveedor(
      id: fila.id,
      nombre: fila.nombre,
      nitCedula: fila.nitCedula,
      contacto: fila.contacto,
      telefono: fila.telefono,
      email: fila.email,
      direccion: fila.direccion,
      ciudad: fila.ciudad,
      notas: fila.notas,
      activo: fila.activo,
      colorHex: fila.colorHex,
      icono: fila.icono,
      creadoEn: fila.creadoEn,
      actualizadoEn: fila.actualizadoEn,
    );
  }

  // Convierte el modelo de dominio a un Companion de Drift para inserción/actualización
  static TablaProveedorCompanion modeloACompanion(Proveedor p) {
    return TablaProveedorCompanion(
      nombre: Value(p.nombre),
      nitCedula: Value(p.nitCedula),
      contacto: Value(p.contacto),
      telefono: Value(p.telefono),
      email: Value(p.email),
      direccion: Value(p.direccion),
      ciudad: Value(p.ciudad),
      notas: Value(p.notas),
      activo: Value(p.activo),
      colorHex: Value(p.colorHex),
      icono: Value(p.icono),
      creadoEn: Value(p.creadoEn),
      actualizadoEn: Value(p.actualizadoEn),
    );
  }
}
