import 'package:drift/drift.dart';

/// Los datos del negocio, en pares clave-valor.
///
/// El archivo estaba **vacío**: el NIT, la dirección y el IVA del taller no se
/// guardaban en ninguna parte, y la tasa de IVA vivía como constante en el
/// código.
///
/// Clave-valor y no una tabla de una sola fila con una columna por dato porque
/// esto crece de a poco —hoy el NIT, mañana el pie de página de la factura— y
/// cada dato nuevo sería un cambio de esquema. El precio es que el valor es
/// texto y hay que interpretarlo; por eso las claves viven en
/// [ClaveConfiguracion] y no se teclean sueltas.
class TablaConfiguracion extends Table {
  @override
  String get tableName => 'configuracion';

  IntColumn get id => integer().autoIncrement()();

  /// Una de [ClaveConfiguracion]. Única: un dato, una fila.
  TextColumn get clave => text().unique()();

  TextColumn get valor => text().nullable()();

  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        'CHECK (length(trim(clave)) > 0)',
      ];
}
