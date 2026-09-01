/// En qué estado está una compra.
///
/// Son dos y no más a propósito: una compra o entró al inventario o se
/// deshizo. No hay «borrador» —la remisión se teclea entera de una vez, como
/// el carrito del mostrador— ni «pagada», que es cosa de la cuenta con el
/// proveedor y no de la mercancía que llegó.
enum EstadoCompra {
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

  static EstadoCompra desdeCodigo(String codigo) => values.firstWhere(
        (e) => e.codigo == codigo,
        orElse: () => EstadoCompra.registrada,
      );
}
