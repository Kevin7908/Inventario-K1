import 'package:drift/drift.dart';

/// El último número usado por cada serie de documentos.
///
/// Hasta ahora cada módulo se numeraba a su manera y las cuatro estaban mal:
///
/// - **Facturas**: insertaban `'FAC-TEMP'` y después lo pisaban con el `id`
///   autoincremental. Dos facturas a la vez chocaban contra el `UNIQUE`, y un
///   `INSERT` fallido se saltaba un número para siempre.
/// - **Cotizaciones, reservas y deudas**: `MAX(numero) + 1`, tres veces el
///   mismo código copiado. Además de la carrera entre el `SELECT` y el
///   `INSERT`, borrar el último documento hacía que el siguiente **reutilizara
///   su número**, que en facturación es lo peor que puede pasar.
///
/// Aquí el número sale de un `UPSERT` atómico dentro de la transacción del
/// documento: si esta se revierte, el número vuelve con ella —no queda hueco—
/// y si dos escrituras compiten, SQLite serializa el incremento.
class TablaConsecutivo extends Table {
  @override
  String get tableName => 'consecutivos';

  /// Uno de `DocumentoConsecutivo.codigo`.
  TextColumn get documento => text()();

  /// Año al que pertenece la serie, o `0` para las que no se reinician.
  IntColumn get periodo => integer()();

  IntColumn get ultimo => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {documento, periodo};

  @override
  List<String> get customConstraints => ['CHECK (ultimo >= 0)'];
}
