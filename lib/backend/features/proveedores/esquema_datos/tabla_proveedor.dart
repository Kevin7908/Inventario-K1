import 'package:drift/drift.dart';

import '../../persona/esquema_datos/tabla_persona.dart';

/// El rol «proveedor» de una persona o empresa.
///
/// La razón social, el NIT, el teléfono y la dirección viven en `personas`
/// —una empresa usa `nombres` como razón social y `tipo_documento = 'NIT'`—.
/// Aquí queda lo propio de surtir al taller.
///
/// **Sin color ni ícono**, por lo mismo que `categorias`: la apariencia de la
/// tarjeta es cosa de la vista, no un dato del proveedor.
@TableIndex(name: 'idx_proveedores_activo', columns: {#activo})
class TablaProveedor extends Table {
  @override
  String get tableName => 'proveedores';

  IntColumn get id => integer().autoIncrement()();

  /// `restrict`: los productos apuntan al proveedor; borrarlo dejaría el
  /// catálogo sin origen.
  IntColumn get personaId => integer()
      .unique()
      .references(TablaPersona, #id, onDelete: KeyAction.restrict)();

  /// Nombre de la persona con la que se habla en esa empresa. No es una FK a
  /// `personas` a propósito: es un dato de agenda, no alguien con quien el
  /// taller tenga relación propia.
  TextColumn get contacto => text().nullable()();

  TextColumn get notas => text().nullable()();

  /// Baja lógica: un proveedor al que ya se le compró no se borra, se
  /// desactiva. Borrarlo dejaría sin origen los productos de su catálogo.
  BoolColumn get activo => boolean().withDefault(const Constant(true))();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();
}
