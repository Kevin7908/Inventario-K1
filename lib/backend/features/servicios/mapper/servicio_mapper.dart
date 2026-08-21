import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../modelo/servicio.dart';

// Alias legible para el tipo generado por Drift
typedef FilaServicio = TablaServicioData;

abstract final class ServicioMapper {

/////////////////////////////////////////////////////////////////
  static Servicio desdeFila(FilaServicio fila) {
    return Servicio(
      id: fila.id,
      nombre: fila.nombre,
      descripcion: fila.descripcion,
      precioSugerido: fila.precioSugerido,
      activo: fila.activo,
      creadoEn: fila.creadoEn,
    );
  }
///////////////////////////////////////////////////////////////////////
  static List<Servicio> desdeFilas(List<FilaServicio> filas) =>
      filas.map(desdeFila).toList(growable: false);

//////////////////////////////////////////////////////////////////////
  static TablaServicioCompanion aCompanionNuevo({
    required String nombre,
    String? descripcion,
    int precioSugerido = 0,
    bool activo = true,
  }) {
    return TablaServicioCompanion.insert(
      nombre: nombre,
      descripcion: Value(descripcion),
      precioSugerido: Value(precioSugerido),
      activo: Value(activo),
      // `creado_en` lo pone el default de la tabla.
    );
  }
///////////////////////////////////////////////////////////////////////
  static TablaServicioCompanion aCompanionActualizar({
    required int id,
    required String nombre,
    String? descripcion,
    required int precioSugerido,
    required bool activo,
  }) {
    return TablaServicioCompanion(
      id: Value(id),
      nombre: Value(nombre),
      descripcion: Value(descripcion),
      precioSugerido: Value(precioSugerido),
      activo: Value(activo),
    );
  }
}