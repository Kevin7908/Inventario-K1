import 'package:drift/drift.dart';

import '../../autenticacion/esquema_datos/tabla_usuario.dart';
import '../../productos/esquema_datos/tabla_producto.dart';
import 'tabla_reserva.dart';

/// Lo que se apartó: un producto y su cantidad, al precio pactado ese día.
///
/// Apartar saca el producto del inventario disponible aunque siga en la
/// bodega, así que cada línea tiene su movimiento en `movimientos_inventario`.
@TableIndex(name: 'idx_reserva_items_reserva', columns: {#reservaId})
@TableIndex(name: 'idx_reserva_items_producto', columns: {#productoId})
// Cubre el WHERE usuarioId = ? de «qué anotó esta cuenta».
@TableIndex(name: 'idx_reserva_items_usuario', columns: {#usuarioId})
class TablaReservaItem extends Table {
  @override
  String get tableName => 'reserva_items';

  IntColumn get id => integer().autoIncrement()();

  /// `cascade`: una línea no existe sin su reserva.
  IntColumn get reservaId => integer()
      .references(TablaReserva, #id, onDelete: KeyAction.cascade)();

  /// `restrict`: un producto apartado no se borra del catálogo.
  IntColumn get productoId => integer()
      .references(TablaProducto, #id, onDelete: KeyAction.restrict)();

  /// Quién anotó **esta línea**, que no siempre es quien abrió el documento:
  /// el editor guarda solo y el apartado puede pasar de un turno a otro
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

  /// Precio congelado al apartar, en pesos enteros.
  IntColumn get precioUnitario => integer()();

  @override
  List<String> get customConstraints => [
        'CHECK (cantidad > 0)',
        'CHECK (precio_unitario >= 0)',
      ];
}
