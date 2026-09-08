import '../../../../backend/features/pos/enum/enum_ventas.dart';
import '../../../../backend/features/pos/modelo/venta_detalle.dart';
import '../../../../backend/features/pos/modelo/venta_item.dart';
import '../modelo/bloque_lineas.dart';
import '../modelo/documento_imprimible.dart';
import '../modelo/movimiento_documento.dart';
import '../modelo/negocio_impreso.dart';
import '../../../../core/iva_app.dart';

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
/// - **Sin cliente identificado el papel dice «CONSUMIDOR FINAL»**, que es lo
///   que dice cualquier tirilla de mostrador. Dejar el bloque en blanco haría
///   pensar que el dato se perdió.
/// - **La factura lleva firmas.** Es el papel que se entrega contra la
///   mercancía, así que el pie trae las dos rayas de «Elaborado por» y
///   «Recibido»; en tirilla no se pintan, porque no hay dónde firmar.
///
/// Parámetros:
/// - [venta]: la venta ya cerrada, con sus líneas.
/// - [negocio]: el encabezado, de `leerAjustesImpresion`.
/// - [atendidoPor]: nombre de quien la registró.
/// - [vendedor]: quién hizo la venta, si no es el mismo que la registró.
/// - [nota]: la letra pequeña del pie, de `ClaveConfiguracion.notaFactura`.
///
/// Ejemplo:
/// ```dart
/// final doc = documentoDeVenta(venta: venta, negocio: negocio);
/// ```
DocumentoImprimible documentoDeVenta({
  required VentaDetalle venta,
  required NegocioImpreso negocio,
  String? atendidoPor,
  String? vendedor,
  String? nota,
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
    destinatario: venta.clienteId == null
        ? DestinatarioImpreso.consumidorFinal
        : DestinatarioImpreso(
            nombre: venta.clienteNombre,
            documento: venta.clienteDocumento,
            direccion: venta.clienteDireccion,
            ciudad: venta.clienteCiudad,
            telefono: venta.clienteTelefono,
            correo: venta.clienteCorreo,
          ),
    atendidoPor: atendidoPor,
    vendedor: vendedor,
    conFirmas: true,
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
    etiquetaIva: etiquetaIva,
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
    nota: _pie(venta, nota),
  );
}

/// El pie: de qué orden viene la factura y la letra pequeña del taller.
///
/// Devuelve `null` si no hay ninguna de las dos, para que el impreso no
/// reserve el renglón. Las dos juntas van en la misma línea porque el pie de
/// la carta es una sola franja.
String? _pie(VentaDetalle venta, String? notaTaller) {
  final partes = [
    if (venta.numeroOrden != null)
      'Corresponde a la orden de servicio ${venta.numeroOrden}.',
    ?notaTaller?.trim().nullSiVacio,
  ];
  return partes.isEmpty ? null : partes.join('  ');
}

extension on String {
  /// El texto, o `null` si está vacío. Evita el `if` repetido en cada pie.
  String? get nullSiVacio => isEmpty ? null : this;
}

LineaDocumento _linea(VentaItem item) => LineaDocumento(
      descripcion: item.descripcion,
      codigo: item.sku.isEmpty ? null : item.sku,
      unidad: item.unidad,
      cantidad: item.cantidad,
      precioUnitario: item.precioUnitario,
      subtotal: item.subtotal,
    );
