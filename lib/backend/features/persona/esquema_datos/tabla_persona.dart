import 'package:drift/drift.dart';

/// Identidad y contacto de una persona —o de una empresa, en el caso de un
/// proveedor.
///
/// Cliente, técnico, proveedor y usuario son **roles**: cada uno tiene su
/// propia tabla con lo que le es propio y apunta aquí con `persona_id`. Antes
/// las cuatro repetían documento, nombres, apellidos, teléfono y email, así
/// que un mismo señor dado de alta como cliente y como técnico terminaba con
/// dos teléfonos que se desincronizaban solos.
///
/// Una persona puede tener varios roles a la vez; lo que no puede es tener el
/// mismo dos veces —`persona_id` es único dentro de cada tabla de rol.
@TableIndex(name: 'idx_personas_nombres', columns: {#nombres})
class TablaPersona extends Table {
  @override
  String get tableName => 'personas';

  IntColumn get id => integer().autoIncrement()();

  /// Qué clase de documento es el de [documento]. Un proveedor empresa usa
  /// `NIT`; una persona natural, `CC`.
  TextColumn get tipoDocumento => text().withDefault(const Constant('CC'))();

  /// Cédula, NIT o pasaporte, ya normalizado (sin puntos, guiones ni espacios).
  ///
  /// Es la llave por la que se reconoce a alguien que ya está registrado.
  /// Nullable porque se le puede vender a quien no da documento, y SQLite
  /// admite varios NULL bajo un `UNIQUE`: la restricción no estorba.
  TextColumn get documento => text().nullable().unique()();

  /// Nombres de pila, o razón social si es una empresa.
  TextColumn get nombres => text()();

  TextColumn get apellidos => text().nullable()();

  /// Ya normalizado (solo dígitos) y **único**: el mismo número no puede estar
  /// en dos fichas. Como vive en `personas`, la restricción es común a los
  /// cuatro roles —cliente, técnico, proveedor y cuenta—, que es justo lo que
  /// se busca: si el número ya está, es la misma persona y hay que reusar su
  /// ficha en vez de crear otra.
  ///
  /// Nullable porque no todo el mundo deja teléfono, y SQLite admite varios
  /// NULL bajo un `UNIQUE`.
  TextColumn get telefono => text().nullable().unique()();
  TextColumn get email => text().nullable()();
  TextColumn get direccion => text().nullable()();
  TextColumn get ciudad => text().nullable()();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        "CHECK (tipo_documento IN ('CC', 'NIT', 'CE', 'PA', 'TI'))",
        "CHECK (length(trim(nombres)) > 0)",
      ];
}
