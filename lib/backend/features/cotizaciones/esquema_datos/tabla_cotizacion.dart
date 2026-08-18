import 'package:drift/drift.dart';

import '../../clientes/esquema_datos/tabla_cliente.dart';
import '../../motos/esquema_datos/tabla_moto.dart';

/// Una cotización: lo que costaría el trabajo, sin compromiso.
///
/// No lleva columna `estado`. Vigente, por vencer o vencida se **deducen** de
/// [vigenciaHasta] comparándola con hoy, así que guardarlo sería un dato que
/// caduca solo y hay que recalcular con un cron. `EstadoCotizacion` es un
/// cálculo, no una columna.
///
/// Tampoco lleva `total`: era `subtotal + iva`, dos columnas de su misma fila.
/// Lo calcula `CotizacionResumen.total`. `subtotal` sí se guarda —es caché de
/// la suma de las líneas, que la lista muestra sin abrirlas— e `iva` también,
/// porque es la tasa que se aplicó ese día y no se recalcula al cambiar la
/// del negocio.
@TableIndex(name: 'idx_cotizaciones_cliente', columns: {#clienteId})
@TableIndex(name: 'idx_cotizaciones_moto', columns: {#motoId})
@TableIndex(name: 'idx_cotizaciones_creado', columns: {#creadoEn})
@TableIndex(name: 'idx_cotizaciones_vigencia', columns: {#vigenciaHasta})
class TablaCotizacion extends Table {
  @override
  String get tableName => 'cotizaciones';

  IntColumn get id => integer().autoIncrement()();

  /// Consecutivo visible, del estilo `COT-0007`.
  TextColumn get numero => text().unique()();

  /// `setNull` en las dos: la cotización sigue siendo válida sin cliente ni
  /// moto —se cotiza de palabra y se asigna después—, así que borrar uno de
  /// ellos no puede llevársela.
  IntColumn get clienteId => integer()
      .nullable()
      .references(TablaCliente, #id, onDelete: KeyAction.setNull)();

  IntColumn get motoId => integer()
      .nullable()
      .references(TablaMoto, #id, onDelete: KeyAction.setNull)();

  /// Los dos en pesos enteros.
  IntColumn get subtotal => integer().withDefault(const Constant(0))();
  IntColumn get iva => integer().withDefault(const Constant(0))();

  /// Hasta cuándo se respeta el precio. Fecha sin hora, guardada a medianoche.
  DateTimeColumn get vigenciaHasta => dateTime()();

  TextColumn get notas => text().nullable()();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        'CHECK (length(trim(numero)) > 0)',
        'CHECK (subtotal >= 0 AND iva >= 0)',
      ];
}
