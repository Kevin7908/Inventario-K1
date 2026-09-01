import 'package:drift/drift.dart';

import '../../motos/esquema_datos/tabla_marca_moto.dart';
import '../../motos/esquema_datos/tabla_modelo_moto.dart';
import 'tabla_producto.dart';

/// A qué motos le sirve un repuesto.
///
/// Antes esto caía en `productos.descripcion` como texto libre, así que la
/// pregunta que el mostrador hace todo el día —«¿esta pastilla le sirve a una
/// Pulsar?»— solo se podía responder leyendo párrafos a ojo.
///
/// **Una línea vale por una marca entera o por un modelo concreto**, nunca por
/// las dos: el aceite le sirve a toda Yamaha y la pastilla solo a la FZ 2.0.
/// Obligar a listar los modelos uno por uno para el primer caso llenaría la
/// tabla de filas que dicen lo mismo.
///
/// Se resuelve con **dos columnas nulables y un `CHECK`**, no con el par
/// `referencia_id` + `tipo`: una FK polimórfica no la puede verificar la base,
/// así que nada impediría que una línea de marca apuntara a un id de modelo.
/// Es la misma solución que ya usan `cotizacion_items` y
/// `movimientos_inventario`.
@TableIndex(name: 'idx_compatibilidades_producto', columns: {#productoId})
@TableIndex(name: 'idx_compatibilidades_marca', columns: {#marcaId})
@TableIndex(name: 'idx_compatibilidades_modelo', columns: {#modeloId})
class TablaProductoCompatibilidad extends Table {
  @override
  String get tableName => 'producto_compatibilidades';

  IntColumn get id => integer().autoIncrement()();

  /// `cascade`: la compatibilidad no existe sin su producto. No es un
  /// documento contable —no hay pasado que conservar—, es una etiqueta del
  /// catálogo, así que se va con él.
  IntColumn get productoId => integer()
      .references(TablaProducto, #id, onDelete: KeyAction.cascade)();

  /// `restrict` en las dos: una marca o un modelo con repuestos declarados no
  /// se borra del catálogo; se da de baja (§1.4).
  IntColumn get marcaId => integer()
      .nullable()
      .references(TablaMarcaMoto, #id, onDelete: KeyAction.restrict)();

  IntColumn get modeloId => integer()
      .nullable()
      .references(TablaModeloMoto, #id, onDelete: KeyAction.restrict)();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        // Exactamente una de las dos. Sin esto cabría una fila con las dos en
        // NULL —que no dice nada— o con las dos puestas —que se contradice si
        // el modelo no es de esa marca—.
        'CHECK ((marca_id IS NOT NULL AND modelo_id IS NULL) OR '
            '(marca_id IS NULL AND modelo_id IS NOT NULL))',
      ];

  /// La misma compatibilidad no se declara dos veces para un producto.
  ///
  /// SQLite trata cada NULL como distinto bajo un `UNIQUE`, así que esta clave
  /// **no** impide repetir por sí sola: la comprobación de verdad la hace el
  /// repositorio antes de insertar. Se declara igual porque documenta la
  /// intención donde vive el esquema y cubre el caso de las dos columnas
  /// puestas, que el `CHECK` ya prohíbe por otro lado.
  @override
  List<Set<Column>> get uniqueKeys => [
        {productoId, marcaId, modeloId},
      ];
}
