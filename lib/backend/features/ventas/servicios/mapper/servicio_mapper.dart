import 'package:drift/drift.dart';

import '../../../../share/database/app_db.dart';
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
    bool activo = true,
  }) {
    return TablaServicioCompanion.insert(
      nombre: nombre,
      descripcion: Value(descripcion),
      activo: Value(activo),
      creadoEn: Value(DateTime.now().toLocal().toIso8601String()),
    );
  }
///////////////////////////////////////////////////////////////////////
  static TablaServicioCompanion aCompanionActualizar({
    required int id,
    required String nombre,
    String? descripcion,
    required bool activo,
  }) {
    return TablaServicioCompanion(
      id: Value(id),
      nombre: Value(nombre),
      descripcion: Value(descripcion),
      activo: Value(activo),
    );
  }
}