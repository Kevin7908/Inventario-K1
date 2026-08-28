import 'package:drift/drift.dart';

import '../../especializacion/esquema_datos/tabla_especializacion.dart';
import '../../persona/esquema_datos/tabla_persona.dart';

/// El rol «técnico» de una persona.
///
/// Igual que `clientes`, no repite identidad ni contacto: eso vive en
/// `personas`. Aquí queda lo laboral.
@TableIndex(name: 'idx_tecnicos_especializacion', columns: {#especializacionId})
@TableIndex(name: 'idx_tecnicos_activo', columns: {#activo})
class TablaTecnico extends Table {
  @override
  String get tableName => 'tecnicos';

  IntColumn get id => integer().autoIncrement()();

  /// `restrict`: las tareas de orden y los detalles de venta apuntan al
  /// técnico; borrarlo dejaría facturas sin autor.
  IntColumn get personaId => integer()
      .unique()
      .references(TablaPersona, #id, onDelete: KeyAction.restrict)();

  /// `setNull`: si se borra la especialización, el técnico sigue existiendo,
  /// solo queda sin clasificar.
  IntColumn get especializacionId => integer()
      .nullable()
      .references(TablaEspecializacion, #id, onDelete: KeyAction.setNull)();

  RealColumn get salarioBase => real().nullable()();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        'CHECK (salario_base IS NULL OR salario_base >= 0)',
      ];
}
