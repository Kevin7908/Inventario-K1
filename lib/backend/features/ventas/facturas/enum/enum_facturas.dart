enum TipoVenta {
  servicio,
  mostrador;

  static TipoVenta desdeTexto(String v) => switch (v.toUpperCase()) {
        'SERVICIO'  => TipoVenta.servicio,
        'MOSTRADOR' => TipoVenta.mostrador,
        _           => TipoVenta.servicio,
      };

  String get aTexto => name.toUpperCase();

  String get etiqueta => switch (this) {
        TipoVenta.servicio  => 'Servicio',
        TipoVenta.mostrador => 'Mostrador',
      };
}

enum MetodoPago {
  efectivo,
  tarjeta,
  transferencia,
  credito;

  static MetodoPago desdeTexto(String v) => switch (v.toUpperCase()) {
        'EFECTIVO'      => MetodoPago.efectivo,
        'TARJETA'       => MetodoPago.tarjeta,
        'TRANSFERENCIA' => MetodoPago.transferencia,
        'CREDITO'       => MetodoPago.credito,
        _               => MetodoPago.efectivo,
      };

  String get aTexto => name.toUpperCase();

  String get etiqueta => switch (this) {
        MetodoPago.efectivo      => 'Efectivo',
        MetodoPago.tarjeta       => 'Tarjeta',
        MetodoPago.transferencia => 'Transferencia',
        MetodoPago.credito       => 'Crédito',
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
