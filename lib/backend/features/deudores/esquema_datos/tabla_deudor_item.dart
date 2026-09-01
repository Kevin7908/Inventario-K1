import 'package:drift/drift.dart';

import '../../autenticacion/esquema_datos/tabla_usuario.dart';
import '../../productos/esquema_datos/tabla_producto.dart';
import 'tabla_deudor.dart';

/// Lo que se fió: un producto y su cantidad, al precio del día en que salió.
///
/// **El precio se copia a propósito** (§1.2 de `REGLAS_BD.md`): la deuda es un
/// documento cerrado, y si mañana sube el repuesto no puede subir lo que este
/// cliente quedó debiendo.
///
/// Cada línea tiene su movimiento en `movimientos_inventario` con tipo
/// `SALIDA_FIADO`, porque fiar **saca la mercancía del taller de verdad**: no
/// es una salida contable como la de una reserva, es un repuesto que se fue
/// montado en una moto.
@TableIndex(name: 'idx_deudor_items_deudor', columns: {#deudorId})
@TableIndex(name: 'idx_deudor_items_producto', columns: {#productoId})
// Cubre el WHERE usuarioId = ? de «qué anotó esta cuenta».
@TableIndex(name: 'idx_deudor_items_usuario', columns: {#usuarioId})
class TablaDeudorItem extends Table {
  @override
  String get tableName => 'deudor_items';

  IntColumn get id => integer().autoIncrement()();

  /// `cascade`: una línea no existe sin su deuda.
  IntColumn get deudorId =>
      integer().references(TablaDeudor, #id, onDelete: KeyAction.cascade)();

  /// `restrict`: un producto que alguien debe no se borra del catálogo.
  IntColumn get productoId => integer()
      .references(TablaProducto, #id, onDelete: KeyAction.restrict)();

  /// Quién anotó **esta línea**, que no siempre es quien abrió el documento:
  /// el editor guarda solo y el fiado puede pasar de un turno a otro
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

  RealColumn get cantidad => real()();

  /// Precio congelado al fiar, en pesos enteros.
  IntColumn get precioUnitario => integer()();

  @override
  List<String> get customConstraints => [
        'CHECK (cantidad > 0)',
        'CHECK (precio_unitario >= 0)',
      ];

  /// El mismo producto no abre dos líneas en la misma deuda: se le suma
  /// cantidad a la que ya está, como en el carrito.
  @override
  List<Set<Column>> get uniqueKeys => [
        {deudorId, productoId},
      ];
}
