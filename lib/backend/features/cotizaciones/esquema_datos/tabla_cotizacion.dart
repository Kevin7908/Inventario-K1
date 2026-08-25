import 'package:drift/drift.dart';

import '../../autenticacion/esquema_datos/tabla_usuario.dart';
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
/// Lo calcula `CotizacionResumen.total`, que además resta el descuento.
/// `subtotal` sí se guarda —es caché de la suma de las líneas, que la lista
/// muestra sin abrirlas— e `iva` también, porque es la tasa que se aplicó ese
/// día y no se recalcula al cambiar la del negocio.
@TableIndex(name: 'idx_cotizaciones_cliente', columns: {#clienteId})
@TableIndex(name: 'idx_cotizaciones_moto', columns: {#motoId})
@TableIndex(name: 'idx_cotizaciones_creado', columns: {#creadoEn})
@TableIndex(name: 'idx_cotizaciones_vigencia', columns: {#vigenciaHasta})
@TableIndex(name: 'idx_cotizaciones_usuario', columns: {#usuarioId})
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

  /// Los tres en pesos enteros.
  IntColumn get subtotal => integer().withDefault(const Constant(0))();

  /// Rebaja sobre el subtotal, en pesos. Como los precios ya traen el IVA
  /// dentro, rebajar aquí rebaja exactamente eso de lo que paga el cliente.
  IntColumn get descuento => integer().withDefault(const Constant(0))();

  IntColumn get iva => integer().withDefault(const Constant(0))();

  /// Hasta cuándo se respeta el precio. Fecha sin hora, guardada a medianoche.
  DateTimeColumn get vigenciaHasta => dateTime()();

  TextColumn get notas => text().nullable()();

  /// Quién lo registró. `restrict`: borrar la cuenta destruiría la atribución
  /// de lo que esa persona hizo, que es justo lo que esta columna existe para
  /// conservar.
  ///
  /// `NOT NULL` **y sin valor por defecto**, a propósito: así el
  /// `Companion.insert` que genera Drift lo exige como parámetro obligatorio y
  /// un método de escritura nuevo que se olvide del autor no compila.
  IntColumn get usuarioId => integer()
      .references(TablaUsuario, #id, onDelete: KeyAction.restrict)();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        'CHECK (length(trim(numero)) > 0)',
        'CHECK (subtotal >= 0 AND iva >= 0 AND descuento >= 0)',
        // Un descuento mayor que el subtotal dejaría el total en negativo. El
        // repositorio ya lo recorta; esto es la red que ninguna ruta se salta.
        'CHECK (descuento <= subtotal)',
      ];
}
