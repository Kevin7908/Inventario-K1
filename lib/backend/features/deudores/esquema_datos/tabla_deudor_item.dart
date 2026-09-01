import 'package:drift/drift.dart';

import '../../autenticacion/esquema_datos/tabla_usuario.dart';
import '../../productos/esquema_datos/tabla_producto.dart';
import 'tabla_deudor.dart';

/// Lo que se fió: qué se llevó el cliente, cuánto y a qué precio salió.
///
/// **El precio y la descripción se copian a propósito** (§1.2 de
/// `REGLAS_BD.md`): la deuda es un documento cerrado, y si mañana sube el
/// repuesto —o le cambian el nombre— no puede cambiar lo que este cliente
/// quedó debiendo.
///
/// **[productoId] es nulable desde que una orden se puede cerrar a crédito.**
/// Lo fiado no siempre es una pieza del catálogo: la mano de obra y los
/// cargos sueltos de la orden se cobran igual y tienen que constar en la
/// deuda, o el total no coincidiría con el de la orden. Por eso manda
/// [descripcion], que va `NOT NULL` y siempre dice qué es la línea; la FK
/// sigue estando cuando hay producto detrás, para poder cruzar la cartera con
/// el inventario.
///
/// Una línea **con producto y sin orden** tiene su movimiento en
/// `movimientos_inventario` con tipo `SALIDA_FIADO`, porque fiar de mostrador
/// **saca la mercancía del taller de verdad**: no es una salida contable como
/// la de una reserva, es un repuesto que se fue montado en una moto. Las
/// líneas de una deuda con `orden_id` **no mueven nada**: ese repuesto ya
/// salió al anotarse en la orden, y descontarlo otra vez es justo el bug que
/// el cierre a crédito vino a cerrar.
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

  /// El producto, cuando la línea es una pieza. `null` en la mano de obra y
  /// en los cargos que llegan de una orden cerrada a crédito.
  ///
  /// `restrict`: un producto que alguien debe no se borra del catálogo.
  IntColumn get productoId => integer()
      .nullable()
      .references(TablaProducto, #id, onDelete: KeyAction.restrict)();

  /// Qué es la línea, congelado. Del producto sale su nombre; de una tarea,
  /// el del servicio; de un cargo suelto, lo que se escribió a mano.
  TextColumn get descripcion => text()();

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
        'CHECK (length(trim(descripcion)) > 0)',
      ];

  // **Sin `UNIQUE (deudor_id, producto_id)`**, y es una decisión, no un
  // olvido. Esa regla —«el mismo producto no abre dos líneas: se le suma
  // cantidad a la que ya está, como en el carrito»— solo vale para lo que se
  // anota a mano, y eso lo sigue haciendo `RepositorioDeudores.agregarItem`.
  // Una deuda que copia una orden es otra cosa: la orden admite el mismo
  // repuesto en dos renglones a precios distintos —uno con rebaja, otro sin
  // ella— y fundirlos para que cupieran en la restricción cambiaría el
  // importe del documento. Que esas líneas no se puedan tocar después lo
  // garantiza la guarda de `guardas_sql.dart`.
}
