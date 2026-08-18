import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../modelo/persona.dart';

abstract final class PersonaMapper {
  PersonaMapper._();

  static DatosPersona filaAModelo(TablaPersonaData fila) => DatosPersona(
        personaId: fila.id,
        tipoDocumento: TipoDocumento.desdeCodigo(fila.tipoDocumento),
        documento: fila.documento,
        nombres: fila.nombres,
        apellidos: fila.apellidos,
        telefono: fila.telefono,
        email: fila.email,
        direccion: fila.direccion,
        ciudad: fila.ciudad,
      );

  /// El documento se normaliza aquí, en el único punto por el que pasa todo lo
  /// que se guarda. Así ningún formulario puede colar «1.098.765».
  static TablaPersonaCompanion modeloACompanion(DatosPersona modelo) =>
      TablaPersonaCompanion(
        tipoDocumento: Value(modelo.tipoDocumento.codigo),
        documento: Value(normalizarDocumento(modelo.documento)),
        nombres: Value(modelo.nombres.trim()),
        apellidos: Value(modelo.apellidos),
        telefono: Value(modelo.telefono),
        email: Value(modelo.email),
        direccion: Value(modelo.direccion),
        ciudad: Value(modelo.ciudad),
        actualizadoEn: Value(DateTime.now()),
      );
}
