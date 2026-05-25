import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../modelo/especializacion.dart';

// El tipo generado por Drift para una fila de TablaEspecializacion
// se llama TablaEspecializacionData (convención: <NombreTabla>Data).
typedef FilaEspecializacion = TablaEspecializacionData;

abstract final class EspecializacionMapper {
  static Especializacion desdeFila(FilaEspecializacion fila) {
    return Especializacion(
      id: fila.id,
      nombre: fila.nombre,
      descripcion: fila.descripcion,
    );
  }

  static List<Especializacion> desdeFilas(List<FilaEspecializacion> filas) => filas.map(desdeFila).toList(growable: false);

  static TablaEspecializacionCompanion aCompanionNuevo({
    required String nombre,
    String? descripcion,
  }) {
    return TablaEspecializacionCompanion.insert(
      nombre: nombre,
      descripcion: Value(descripcion),
    );
  }

  static TablaEspecializacionCompanion aCompanionActualizar({
    required int id,
    required String nombre,
    String? descripcion,
  }) {
    return TablaEspecializacionCompanion(
      id: Value(id),
      nombre: Value(nombre),
      descripcion: Value(descripcion),
    );
  }
}