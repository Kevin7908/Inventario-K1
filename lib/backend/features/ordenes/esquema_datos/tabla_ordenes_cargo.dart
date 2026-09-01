import 'package:drift/drift.dart';

import '../../autenticacion/esquema_datos/tabla_usuario.dart';
import 'tabla_ordenes_servicio.dart';

/// Un cargo suelto de la orden: descripción y precio escritos a mano, sin
/// catálogo detrás.
///
/// Es la "línea libre" del editor, el mismo tercer tipo que ya tenían las
/// cotizaciones: el repuesto que se consigue en la esquina y no está en el
/// inventario, el domicilio, el lavado que nadie dio de alta como servicio.
///
/// **Tabla propia y no una columna más en repuestos o tareas** (§1.1): una
/// tarea tiene técnico y estado de completado, un repuesto tiene cantidad y
/// descuenta stock, y un cargo no tiene nada de eso. Meterlos juntos dejaría
/// media tabla en NULL según el tipo de fila.
///
/// No descuenta inventario a propósito: si el repuesto estuviera en el
/// catálogo, sería un repuesto.
@TableIndex(name: 'idx_ordenes_cargos_orden', columns: {#ordenId})
// Cubre el WHERE usuarioId = ? de «qué anotó esta cuenta».
@TableIndex(name: 'idx_ordenes_cargos_usuario', columns: {#usuarioId})
class TablaOrdenesCargo extends Table {
  @override
  String get tableName => 'ordenes_cargos';

  IntColumn get id => integer().autoIncrement()();

  /// `cascade`: un cargo no existe sin su orden.
  IntColumn get ordenId => integer()
      .references(TablaOrdenesServicio, #id, onDelete: KeyAction.cascade)();

  /// Quién anotó **esta línea**, que no siempre es quien abrió el documento:
  /// el editor guarda solo y el trabajo del taller puede pasar de un turno a otro
  /// (`REGLAS_BD.md` §7.0).
  ///
  /// `NOT NULL` y sin valor por defecto **a propósito**: así el
  /// `Companion.insert` que genera Drift lo exige como parámetro, y un método
  /// de escritura nuevo que se olvide del autor no compila. La garantía la da
  /// el compilador, no la disciplina.
  ///
  /// `restrict`: la cuenta que anotó algo no se borra mientras eso exista.
  IntColumn get usuarioId => integer()
      .references(TablaUsuario, #id, onDelete: KeyAction.restrict)();

  TextColumn get descripcion => text()();

  /// Pesos enteros, IVA incluido, como todo precio del sistema.
  IntColumn get precio => integer().withDefault(const Constant(0))();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        'CHECK (precio >= 0)',
        'CHECK (length(trim(descripcion)) > 0)',
      ];
}
