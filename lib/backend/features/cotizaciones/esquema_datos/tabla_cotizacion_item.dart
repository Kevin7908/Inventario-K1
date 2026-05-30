import 'package:drift/drift.dart';
import 'tabla_cotizacion.dart';

class TablaCotizacionItem extends Table {
  @override
  String get tableName => 'cotizacion_items';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get cotizacionId =>
      integer().references(TablaCotizacion, #id, onDelete: KeyAction.cascade)();
  TextColumn get tipoItem => text()(); // 'PRODUCTO' | 'SERVICIO'
  IntColumn get referenciaId => integer().nullable()();
  TextColumn get descripcion => text()();
  RealColumn get cantidad => real()();
  IntColumn get precioUnitario => integer()();
  IntColumn get subtotal => integer()();
}
