enum TipoItemCotizacion { producto, servicio }

extension TipoItemCotizacionExt on TipoItemCotizacion {
  String get valor {
    switch (this) {
      case TipoItemCotizacion.producto:
        return 'PRODUCTO';
      case TipoItemCotizacion.servicio:
        return 'SERVICIO';
    }
  }

  static TipoItemCotizacion desdeTexto(String texto) {
    switch (texto.toUpperCase()) {
      case 'SERVICIO':
        return TipoItemCotizacion.servicio;
      default:
        return TipoItemCotizacion.producto;
    }
  }
}
