/// Qué es una línea de la cotización.
///
/// Se guarda como texto en `cotizacion_items.tipo_item`, así que sumar un tipo
/// no cuesta migración.
///
/// La diferencia no es cosmética: decide de dónde sale el precio y qué se puede
/// reservar.
/// - [producto]: sale del catálogo y tiene stock. Es lo único reservable.
/// - [servicio]: sale del catálogo de Configuración → Servicios, que **no
///   guarda precio**: la mano de obra la cotiza cada técnico, así que el precio
///   se teclea en la línea.
/// - [libre]: descripción y precio escritos a mano, sin catálogo detrás
///   (`referenciaId` queda en `null`). Para el repuesto que se consigue afuera
///   o un cargo puntual.
enum TipoItemCotizacion {
  producto('PRODUCTO', 'Producto'),
  servicio('SERVICIO', 'Servicio'),
  libre('LIBRE', 'Línea libre');

  const TipoItemCotizacion(this.valor, this.etiqueta);

  /// Lo que va en la base de datos.
  final String valor;

  /// Lo que ve el usuario.
  final String etiqueta;

  /// Solo los productos descuentan inventario y pueden pasar a una reserva.
  bool get esReservable => this == TipoItemCotizacion.producto;

  /// El precio se teclea en la línea en vez de heredarse de un catálogo.
  bool get precioManual => this != TipoItemCotizacion.producto;

  /// Traduce el texto guardado. Cae en [producto] si no se reconoce: es lo que
  /// había en las filas creadas antes de que existieran los otros tipos.
  static TipoItemCotizacion desdeTexto(String? texto) => values.firstWhere(
        (t) => t.valor == (texto ?? '').toUpperCase(),
        orElse: () => TipoItemCotizacion.producto,
      );
}
