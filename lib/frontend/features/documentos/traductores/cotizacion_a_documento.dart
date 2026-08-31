import '../../../../backend/features/cotizaciones/enum/enum_cotizacion.dart';
import '../../../../backend/features/cotizaciones/modelo/cotizacion_detalle.dart';
import '../../../../backend/features/cotizaciones/modelo/cotizacion_item.dart';
import '../../../../core/formato.dart';
import '../modelo/bloque_lineas.dart';
import '../modelo/documento_imprimible.dart';
import '../modelo/negocio_impreso.dart';

/// Traduce una cotización a papel.
///
/// Una cotización no es un cobro: es una **promesa con fecha de caducidad**.
/// Por eso no lleva pagos ni saldo, y la vigencia va al pie en letra visible:
/// es la única condición que el cliente tiene que recordar.
///
/// Decisiones que se toman aquí:
///
/// - **Repuestos y servicios en bloques separados**, y solo titulados si hay
///   de los dos, igual que en la factura de venta.
/// - **El IVA se lee del documento**, no se recalcula: la cotización lo guardó
///   con la tasa vigente el día que se emitió.
/// - **Las notas del vendedor se imprimen** junto a la vigencia. Suelen decir
///   cosas que el total no dice («no incluye desmonte»).
///
/// Parámetros:
/// - [cotizacion]: la cotización con sus líneas.
/// - [negocio]: el encabezado, de `leerNegocioImpreso`.
/// - [atendidoPor]: quién la elaboró.
///
/// Ejemplo:
/// ```dart
/// final doc = documentoDeCotizacion(cotizacion: detalle, negocio: negocio);
/// ```
DocumentoImprimible documentoDeCotizacion({
  required CotizacionDetalle cotizacion,
  required NegocioImpreso negocio,
  String? atendidoPor,
}) {
  final resumen = cotizacion.resumen;
  final productos = cotizacion.items
      .where((i) => i.tipoItem == TipoItemCotizacion.producto)
      .toList();
  final servicios = cotizacion.items
      .where((i) => i.tipoItem != TipoItemCotizacion.producto)
      .toList();
  final mixta = productos.isNotEmpty && servicios.isNotEmpty;

  return DocumentoImprimible(
    negocio: negocio,
    titulo: 'Cotización',
    numero: resumen.numero,
    fecha: resumen.creadoEn,
    cliente: resumen.nombreCliente,
    documentoCliente: resumen.nombreMoto.isEmpty ? null : resumen.nombreMoto,
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
    subtotal: resumen.subtotal,
    descuento: resumen.descuento,
    iva: resumen.iva > 0 ? resumen.iva : null,
    total: resumen.total,
    nota: _pie(resumen.vigenciaHasta, resumen.notas),
  );
}

/// La vigencia siempre, y las notas del vendedor detrás si las hay.
String _pie(DateTime vigencia, String? notas) {
  final texto = 'Cotización válida hasta el ${formatearFecha(vigencia)}.';
  final extra = (notas ?? '').trim();
  return extra.isEmpty ? texto : '$texto $extra';
}

LineaDocumento _linea(CotizacionItem item) => LineaDocumento(
      descripcion: item.descripcion,
      cantidad: item.cantidad,
      precioUnitario: item.precioUnitario,
      subtotal: item.subtotal,
    );
