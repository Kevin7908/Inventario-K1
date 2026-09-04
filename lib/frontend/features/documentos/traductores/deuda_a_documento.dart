import '../../../../backend/features/deudores/enum/enum_deudor.dart';
import '../../../../backend/features/deudores/modelo/deudor_detalle.dart';
import '../../../../backend/features/deudores/modelo/deudor_item.dart';
import '../../../../backend/features/deudores/modelo/deudor_pago.dart';
import '../../../../backend/features/deudores/modelo/deudor_resumen.dart';
import '../../../../core/formato.dart';
import '../../../../core/iva_app.dart';
import '../modelo/bloque_lineas.dart';
import '../modelo/documento_imprimible.dart';
import '../modelo/movimiento_documento.dart';
import '../modelo/negocio_impreso.dart';

/// Traduce una deuda a papel.
///
/// Lo que el cliente se lleva de una cuenta por cobrar es lo mismo que se
/// lleva de una reserva —cuánto debe, cuánto ha entregado, cuándo y de a
/// cuánto—, con una diferencia de fondo: la reserva es mercancía que espera en
/// la bodega y la deuda es mercancía que ya salió montada en una moto. En el
/// papel eso se nota en el rótulo y en el pie, no en la estructura.
///
/// Decisiones que se toman aquí, y por qué:
///
/// - **Los repuestos y la mano de obra van en bloques separados**, y solo se
///   titulan si hay de los dos, igual que en la factura. Una deuda de
///   mostrador es puro repuesto; la que copia una orden cerrada a crédito trae
///   además tareas y cargos sueltos, que no tienen catálogo detrás. Lo que los
///   distingue es `DeudorItem.esProducto`, es decir la FK, no el texto.
/// - **El saldo se imprime aunque esté en cero**, como en la reserva: quien
///   viene a pedir el papel de una deuda saldada viene justamente a que diga
///   cero. Es lo contrario que en una factura, donde solo estorba.
/// - **El IVA se calcula, no se lee.** Una deuda no lo guarda como lo hace una
///   factura, así que se extrae del total con `ivaIncluidoEn` —los precios lo
///   llevan dentro— y se omite si la tasa es cero.
/// - **El subtotal es la suma de las líneas y `montoTotal` ya viene rebajado.**
///   Por eso el subtotal se reconstruye sumando el descuento al total en vez
///   de sumar las líneas: en la deuda que copia una orden, el descuento se
///   pactó allá y la suma de estas líneas no tiene por qué cuadrar al peso con
///   lo que se fió.
/// - **Una deuda dada por perdida lo dice en el título**, como la factura
///   anulada: el papel no puede sugerir que se sigue cobrando algo que el
///   taller ya descontó de su cartera.
///
/// Parámetros:
/// - [deuda]: la deuda con sus líneas y sus pagos.
/// - [negocio]: el encabezado, de `leerAjustesImpresion`.
/// - [atendidoPor]: quién la atiende.
///
/// Ejemplo:
/// ```dart
/// final doc = documentoDeDeuda(deuda: detalle, negocio: ajustes.negocio);
/// ```
DocumentoImprimible documentoDeDeuda({
  required DeudorDetalle deuda,
  required NegocioImpreso negocio,
  String? atendidoPor,
}) {
  final resumen = deuda.resumen;
  final productos = deuda.items.where((i) => i.esProducto).toList();
  final trabajo = deuda.items.where((i) => !i.esProducto).toList();
  final mixta = productos.isNotEmpty && trabajo.isNotEmpty;

  final pagos = [...deuda.pagos]
    ..sort((a, b) => a.fechaPago.compareTo(b.fechaPago));

  return DocumentoImprimible(
    negocio: negocio,
    titulo: resumen.estado == EstadoDeudor.incobrable
        ? 'Cuenta dada por perdida'
        : 'Cuenta por cobrar',
    numero: resumen.numero,
    fecha: resumen.creadoEn,
    cliente: resumen.nombreCliente,
    documentoCliente: resumen.descripcionMoto,
    atendidoPor: atendidoPor,
    bloques: [
      if (productos.isNotEmpty)
        BloqueLineas(
          titulo: mixta ? 'Repuestos' : null,
          lineas: productos.map(_linea).toList(),
        ),
      if (trabajo.isNotEmpty)
        BloqueLineas(
          titulo: mixta ? 'Mano de obra' : null,
          lineas: trabajo.map(_linea).toList(),
        ),
    ],
    subtotal: resumen.montoTotal + resumen.descuento,
    descuento: resumen.descuento,
    iva: hayIva ? ivaIncluidoEn(resumen.montoTotal) : null,
    total: resumen.montoTotal,
    movimientos: pagos.map(_movimiento).toList(),
    tituloMovimientos: 'Pagos recibidos',
    saldoPendiente: resumen.saldo,
    nota: _pie(resumen),
  );
}

/// El plazo, de dónde salió la deuda y lo que se haya anotado a mano.
///
/// El número de la orden va aquí y no en la cabecera porque el papel de una
/// deuda no es el de la orden: quien lo lea tiene que poder llegar a la otra,
/// pero lo que está cobrando es esto.
String? _pie(DeudorResumen resumen) {
  final partes = <String>[
    if (resumen.fechaVencimiento != null)
      resumen.estaVencida
          ? 'Venció el ${formatearFecha(resumen.fechaVencimiento!)}.'
          : 'Plazo hasta el ${formatearFecha(resumen.fechaVencimiento!)}.',
    if (resumen.numeroOrden != null)
      'Corresponde a la orden de servicio ${resumen.numeroOrden}.',
    if (resumen.numeroOrden == null && (resumen.concepto ?? '').trim().isNotEmpty)
      resumen.concepto!.trim(),
    if ((resumen.notas ?? '').trim().isNotEmpty) resumen.notas!.trim(),
  ];
  return partes.isEmpty ? null : partes.join('  ');
}

LineaDocumento _linea(DeudorItem item) => LineaDocumento(
      descripcion: item.descripcion,
      referencia: item.sku,
      cantidad: item.cantidad,
      precioUnitario: item.precioUnitario,
      subtotal: item.subtotal,
    );

/// Las notas del pago hacen de referencia: es donde el taller anota el número
/// de la transferencia cuando lo hay.
MovimientoDocumento _movimiento(DeudorPago pago) => MovimientoDocumento(
      fecha: pago.fechaPago,
      concepto: pago.metodoPago.etiqueta,
      referencia: pago.notas,
      monto: pago.monto,
    );
