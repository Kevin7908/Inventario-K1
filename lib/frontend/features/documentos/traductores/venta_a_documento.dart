import '../../../../backend/features/pos/enum/enum_ventas.dart';
import '../../../../backend/features/pos/modelo/venta_detalle.dart';
import '../../../../backend/features/pos/modelo/venta_item.dart';
import '../modelo/bloque_lineas.dart';
import '../modelo/documento_imprimible.dart';
import '../modelo/movimiento_documento.dart';
import '../modelo/negocio_impreso.dart';

/// Traduce una venta a papel.
///
/// Es todo lo que el punto de venta necesita saber de la impresión: arma un
/// [DocumentoImprimible] y se acaba su trabajo. Quien pinta es
/// `ConstructorPdf`, que no conoce las ventas.
///
/// Decisiones que se toman aquí, y por qué:
///
/// - **Los repuestos y la mano de obra van en bloques separados**, y solo se
///   titulan si hay de los dos. Una venta de mostrador con puros productos no
///   necesita un encabezado «Repuestos» que no separa nada de nada.
/// - **El IVA se omite cuando es cero.** `core/iva_app.dart` ya decide que la
///   interfaz esconde el renglón en vez de imprimir un `$0`; el papel obedece
///   la misma regla.
/// - **El saldo pendiente solo aparece si lo hay.** Una factura pagada que
///   imprime «Saldo pendiente: $0» siembra la duda que quería despejar.
///
/// Parámetros:
/// - [venta]: la venta ya cerrada, con sus líneas.
/// - [negocio]: el encabezado, de `negocioImpresoProvider`.
/// - [atendidoPor]: nombre de quien la cobró.
///
/// Ejemplo:
/// ```dart
/// final doc = documentoDeVenta(venta: venta, negocio: negocio);
/// ```
DocumentoImprimible documentoDeVenta({
  required VentaDetalle venta,
  required NegocioImpreso negocio,
  String? atendidoPor,
}) {
  final productos = venta.itemsProducto;
  final servicios = venta.itemsServicio;
  final mixta = productos.isNotEmpty && servicios.isNotEmpty;

  return DocumentoImprimible(
    negocio: negocio,
    titulo: venta.estadoPago == EstadoPago.anulada
        ? 'Factura anulada'
        : 'Factura de venta',
    numero: venta.numeroFactura,
    // `creadoEn` es nullable en el modelo, pero una venta guardada siempre la
    // tiene: la columna es `NOT NULL` con valor por defecto.
    fecha: venta.creadoEn ?? DateTime.now(),
    cliente: venta.clienteNombre,
    atendidoPor: atendidoPor,
    bloques: [
      if (productos.isNotEmpty)
        BloqueLineas(
          titulo: mixta ? 'Repuestos' : null,
          lineas: productos.map(_linea).toList(),
        ),
      if (servicios.isNotEmpty)
        BloqueLineas(
          titulo: mixta ? 'Mano de obra' : null,
          lineas: servicios.map(_linea).toList(),
        ),
    ],
    subtotal: venta.subtotal,
    descuento: venta.descuento,
    iva: venta.iva > 0 ? venta.iva : null,
    total: venta.total,
    movimientos: [
      if (venta.totalPagado > 0)
        MovimientoDocumento(
          fecha: venta.creadoEn ?? DateTime.now(),
          concepto: venta.metodoPago.etiqueta,
          monto: venta.totalPagado,
        ),
    ],
    tituloMovimientos: 'Pago recibido',
    saldoPendiente:
        venta.saldoPendiente > 0 ? venta.saldoPendiente : null,
    nota: venta.numeroOrden != null
        ? 'Corresponde a la orden de servicio ${venta.numeroOrden}.'
        : null,
  );
}

LineaDocumento _linea(VentaItem item) => LineaDocumento(
      descripcion: item.descripcion,
      cantidad: item.cantidad,
      precioUnitario: item.precioUnitario,
      subtotal: item.subtotal,
    );
