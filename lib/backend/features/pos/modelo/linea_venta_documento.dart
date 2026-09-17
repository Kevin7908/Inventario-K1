import '../enum/enum_ventas.dart';

/// Una línea de la factura que cierra un documento que ya cobró: la orden
/// entregada, la deuda saldada, la reserva terminada de abonar.
///
/// Es distinta de `LineaVentaMostrador` en dos cosas, y las dos importan:
///
/// - **puede no ser un producto.** Una orden factura mano de obra y cargos
///   sueltos, que no tienen catálogo detrás, así que [productoId] es opcional
///   y hay [tipoItem];
/// - **no mueve inventario.** El stock ya salió cuando se anotó el repuesto en
///   la orden, cuando se apartó la reserva o cuando se abrió la deuda.
///   Volverlo a descontar al facturar lo dejaría en negativo, que es
///   exactamente el error que esta clase separada existe para hacer imposible:
///   quien la usa llama a `registrarVentaDeDocumento`, que no toca el libro
///   mayor.
///
/// El precio viaja desde el documento y no se relee del catálogo: es el que se
/// pactó, y al guardarse en `venta_detalles` queda como snapshot histórico
/// (`REGLAS_BD.md` §1.2).
final class LineaVentaDocumento {
  const LineaVentaDocumento({
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
    this.tipoItem = TipoItem.producto,
    this.productoId,
    this.servicioId,
    this.tecnicoId,
    this.costoUnitario = 0,
  });

  /// Lo que se llevó el cliente, tal como se llamaba ese día.
  final String descripcion;

  /// Puede ser fraccionaria: hay productos por litro y por metro.
  final double cantidad;

  /// Pesos enteros, igual que la columna (§2).
  final int precioUnitario;

  final TipoItem tipoItem;

  /// `null` en la mano de obra y en los cargos sueltos.
  final int? productoId;

  final int? servicioId;

  /// Quién hizo el trabajo, cuando la línea es un servicio. Es lo que el
  /// cliente pregunta si algo vuelve a fallar.
  final int? tecnicoId;

  /// Costo del momento, para el margen. Pesos enteros.
  final int costoUnitario;

  /// Lo que suma la línea. Se redondea aquí y no en el llamador: la cantidad
  /// puede ser fraccionaria y el importe que se cobra, no.
  int get subtotal => (cantidad * precioUnitario).round();
}
