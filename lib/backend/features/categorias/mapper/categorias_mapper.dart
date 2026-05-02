import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../modelo/categoria.dart';

class CategoriaMapper {
  // Convierte una fila de Drift al modelo de dominio
  static Categoria filaAModelo(TablaCategoriaData fila) {
    return Categoria(
      id: fila.id,
      nombre: fila.nombre,
      descripcion: fila.descripcion,
      colorHex: fila.colorHex,
      icono: fila.icono,
      creadoEn: fila.creadoEn,
      actualizadoEn: fila.actualizadoEn,
    );
  }

  // Convierte el modelo de dominio a un Companion de Drift para inserción/actualización
  static TablaCategoriaCompanion modeloACompanion(Categoria categoria) {
    return TablaCategoriaCompanion(
      id: categoria.id != null ? Value(categoria.id!) : const Value.absent(),
      nombre: Value(categoria.nombre),
      descripcion: Value(categoria.descripcion),
      colorHex: Value(categoria.colorHex),
      icono: Value(categoria.icono),
      actualizadoEn: Value(DateTime.now()),
    );
  }
}
