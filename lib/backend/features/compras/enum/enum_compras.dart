/// En qué estado está una compra.
///
/// Son tres y describen las tres cosas que le pasan a una remisión: se está
/// tecleando, se archivó, o se deshizo. No hay «pagada», que es cosa de la
/// cuenta con el proveedor y no de la mercancía que llegó.
///
/// **El borrador no es un documento a medio guardar**: su mercancía ya entró
/// al inventario, porque anotar una línea *es* recibirla. Lo que le falta es
/// que quien recibe diga «ya está todo», y eso es [registrada]: a partir de
/// ahí la remisión se cierra a cambios y cuenta como gasto del mes.
enum EstadoCompra {
  borrador('BORRADOR', 'Borrador'),
  registrada('REGISTRADA', 'Registrada'),
  anulada('ANULADA', 'Anulada');

  const EstadoCompra(this.codigo, this.etiqueta);

  /// Lo que viaja a la columna `estado` y valida su `CHECK`.
  final String codigo;

  /// Lo que se lee en pantalla.
  final String etiqueta;

  /// Fragmento `IN (...)` del `CHECK`, generado desde el enum para que
  /// agregar un estado no obligue a acordarse de la tabla.
  static String get listaSql => values.map((e) => "'${e.codigo}'").join(', ');

  /// Si todavía admite cambios. Solo el borrador: una remisión terminada se
  /// cierra, y una anulada ya devolvió su mercancía.
  bool get admiteCambios => this == EstadoCompra.borrador;

  static EstadoCompra desdeCodigo(String codigo) => values.firstWhere(
        (e) => e.codigo == codigo,
        orElse: () => EstadoCompra.borrador,
      );
}
