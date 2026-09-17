import 'package:drift/drift.dart';

/// Las marcas de moto que atiende el taller.
///
/// Es un catálogo y no un texto libre en `motos.marca`, por lo mismo que las
/// categorías o las unidades de medida (`REGLAS_BD.md` §1.3): con texto libre
/// entran «Yamaha», «yamaha» y «YAMAHA» como tres marcas distintas, y ningún
/// informe puede cruzarlas. La regla ya nombraba este caso.
///
/// **Baja lógica, no borrado** (§1.4): una marca la referencian motos y
/// compatibilidades de producto, así que borrarla rompería el historial.
@TableIndex(name: 'idx_marcas_moto_activo', columns: {#activo})
class TablaMarcaMoto extends Table {
  @override
  String get tableName => 'marcas_moto';

  IntColumn get id => integer().autoIncrement()();

  /// Se guarda ya normalizado —recortado y con la primera en mayúscula— desde
  /// el repositorio. El `UNIQUE` compara byte a byte, así que confiar en un
  /// `LIKE` al consultar dejaría entrar el duplicado (§3.1).
  TextColumn get nombre => text().unique()();

  BoolColumn get activo => boolean().withDefault(const Constant(true))();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        'CHECK (length(trim(nombre)) > 0)',
      ];
}
