import 'package:drift/drift.dart';

import '../../clientes/esquema_datos/tabla_cliente.dart';
import 'tabla_marca_moto.dart';
import 'tabla_modelo_moto.dart';

/// La moto de un cliente.
///
/// `placa` es única: dos motos no pueden compartirla, y en un taller
/// confundirlas es confundir el trabajo. Es nullable porque hay motos sin
/// papeles al día, y SQLite admite varios NULL bajo un `UNIQUE`.
///
/// **La marca y el modelo son FK, no texto** (§1.3). Con texto libre entraban
/// «Yamaha», «yamaha» y «YAMAHA» como tres marcas, y no había forma de
/// preguntarle al catálogo qué repuestos le sirven a esta moto. El cilindraje
/// se fue con ellos: es del modelo, no del ejemplar —todas las Boxer CT100 son
/// de 100 cc—, así que repetirlo aquí era el mismo dato una vez por cliente.
///
/// **Sin número de chasis ni kilometraje inicial.** El chasis no se usaba para
/// nada que la placa no resolviera, y el kilometraje de una moto cambia cada
/// vez que entra al taller: guardar el «inicial» era una foto de un dato vivo
/// que nadie volvía a mirar. Si algún día hace falta seguirlo, va en la orden
/// de servicio —que es donde se toma— y no en la ficha de la moto.
@TableIndex(name: 'idx_motos_cliente', columns: {#clienteId})
@TableIndex(name: 'idx_motos_activo', columns: {#activo})
// Cubren el JOIN con el catálogo al listar y al buscar por marca.
@TableIndex(name: 'idx_motos_marca', columns: {#marcaId})
@TableIndex(name: 'idx_motos_modelo', columns: {#modeloId})
class TablaMoto extends Table {
  @override
  String get tableName => 'motos';

  IntColumn get id => integer().autoIncrement()();

  /// `restrict`: una moto con historial de taller ata a su dueño. Antes era
  /// `NO ACTION`, que en la práctica es «falla con un error críptico».
  IntColumn get clienteId =>
      integer().references(TablaCliente, #id, onDelete: KeyAction.restrict)();

  TextColumn get placa => text().nullable().unique()();

  /// `restrict` en las dos: una marca o un modelo con motos registradas no se
  /// borra del catálogo; se da de baja (§1.4).
  ///
  /// El modelo es nullable y la marca no: en el mostrador la marca siempre se
  /// sabe, y el modelo exacto a veces no está catalogado todavía. Parar la
  /// atención al cliente para dar de alta un modelo sería peor que registrar
  /// la moto con lo que se sabe.
  IntColumn get marcaId => integer()
      .references(TablaMarcaMoto, #id, onDelete: KeyAction.restrict)();

  IntColumn get modeloId => integer()
      .nullable()
      .references(TablaModeloMoto, #id, onDelete: KeyAction.restrict)();

  IntColumn get anio => integer().nullable()();

  TextColumn get color => text().nullable()();

  TextColumn get numeroMotor => text().nullable()();
  TextColumn get notas => text().nullable()();

  BoolColumn get activo => boolean().withDefault(const Constant(true))();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        // Rango generoso a propósito: hay motos clásicas en los talleres.
        'CHECK (anio IS NULL OR (anio BETWEEN 1900 AND 2200))',
      ];
}
