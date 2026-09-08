export '../../../share/dominio/metodo_pago.dart';

/// Por qué puerta entró la plata.
///
/// Las cuatro son ventas y viven en la misma tabla: el historial y el cuadre
/// del día preguntan «cuánto entró hoy», no de qué módulo salió. Antes solo
/// el mostrador escribía en `ventas`, así que los repuestos que se iban en una
/// orden, en una deuda o en una reserva no aparecían en ninguna parte donde se
/// pudieran sumar con lo demás.
enum TipoVenta {
  /// El carrito del punto de venta, cobrado completo.
  mostrador,

  /// Una orden de servicio entregada y pagada de inmediato. La que se fía no
  /// pasa por aquí: la factura la escribe su deuda al saldarse, o se cobraría
  /// dos veces el mismo trabajo.
  servicio,

  /// Una cuenta por cobrar que terminó de pagarse.
  deuda,

  /// Una reserva que se terminó de abonar.
  reserva;

  static TipoVenta desdeTexto(String v) => switch (v.toUpperCase()) {
        'SERVICIO'  => TipoVenta.servicio,
        'MOSTRADOR' => TipoVenta.mostrador,
        'DEUDA'     => TipoVenta.deuda,
        'RESERVA'   => TipoVenta.reserva,
        _           => TipoVenta.servicio,
      };

  String get aTexto => name.toUpperCase();

  String get etiqueta => switch (this) {
        TipoVenta.servicio  => 'Servicio',
        TipoVenta.mostrador => 'Mostrador',
        TipoVenta.deuda     => 'Cuenta por cobrar',
        TipoVenta.reserva   => 'Reserva',
      };
}

enum EstadoPago {
  pagado,
  pendiente,
  anulada;

  static EstadoPago desdeTexto(String v) => switch (v.toUpperCase()) {
        'PAGADO'   => EstadoPago.pagado,
        'PENDIENTE' => EstadoPago.pendiente,
        'ANULADA'  => EstadoPago.anulada,
        _          => EstadoPago.pendiente,
      };

  String get aTexto => name.toUpperCase();

  String get etiqueta => switch (this) {
        EstadoPago.pagado   => 'Pagado',
        EstadoPago.pendiente => 'Pendiente',
        EstadoPago.anulada  => 'Anulada',
      };
}

enum TipoItem {
  producto,
  servicio;

  static TipoItem desdeTexto(String v) => switch (v.toUpperCase()) {
        'PRODUCTO' => TipoItem.producto,
        'SERVICIO' => TipoItem.servicio,
        _          => TipoItem.producto,
      };

  String get aTexto => name.toUpperCase();
}
