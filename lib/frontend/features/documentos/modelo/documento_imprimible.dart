import 'package:equatable/equatable.dart';

import 'bloque_lineas.dart';
import 'movimiento_documento.dart';
import 'negocio_impreso.dart';

/// El papel, sin saber de qué documento salió.
///
/// Es la pieza que evita tener una plantilla por módulo. El punto de venta, las
/// reservas, las cotizaciones y las órdenes son cuatro documentos con la misma
/// forma —un taller que emite, unas líneas, unos totales—, así que cada uno
/// **traduce** su modelo a este y el constructor de PDF pinta uno solo.
///
/// Si un módulo necesita algo que aquí no está, se agrega **aquí** y los cuatro
/// lo ganan. Lo que no se hace es una segunda plantilla: con dos, la letra
/// pequeña de la factura y la de la reserva empiezan a divergir el mismo día.
///
/// Parámetros:
/// - [negocio]: quién emite. Sale de la configuración, no se teclea.
/// - [titulo]: qué es este papel («Factura de venta», «Reserva»).
/// - [numero]: el consecutivo del documento, tal como se guardó.
/// - [fecha]: cuándo se emitió.
/// - [cliente], [documentoCliente]: a quién. Opcionales: el mostrador vende sin
///   pedir cédula.
/// - [atendidoPor]: quién lo hizo, para que el papel diga lo mismo que la
///   bitácora.
/// - [bloques]: las líneas, agrupadas. Un solo bloque sin título es lo normal;
///   una venta con repuestos y mano de obra usa dos.
/// - [subtotal], [descuento], [total]: en pesos enteros, como toda la app.
/// - [iva]: informativo. **Los precios lo llevan incluido** (ver
///   `core/iva_app.dart`), así que este renglón discrimina, no suma. En `null`
///   el renglón no se pinta.
/// - [movimientos]: los pagos recibidos, si el documento los tiene.
/// - [tituloMovimientos]: cómo se llama ese bloque en el papel. Una reserva
///   lista «Abonos recibidos»; una factura de mostrador, «Forma de pago». Es
///   un parámetro y no dos plantillas porque la tabla es la misma —fecha,
///   concepto, monto— y solo cambia el rótulo.
/// - [saldoPendiente]: lo que falta por pagar. En `null` no se pinta.
/// - [nota]: una línea libre al pie (condiciones, vigencia).
///
/// Ejemplo:
/// ```dart
/// final doc = documentoDeVenta(venta: venta, negocio: negocio);
/// final bytes = await ConstructorPdf().construir(doc);
/// ```
class DocumentoImprimible extends Equatable {
  const DocumentoImprimible({
    required this.negocio,
    required this.titulo,
    required this.numero,
    required this.fecha,
    this.cliente,
    this.documentoCliente,
    this.atendidoPor,
    required this.bloques,
    required this.subtotal,
    this.descuento = 0,
    this.iva,
    required this.total,
    this.movimientos = const [],
    this.tituloMovimientos = 'Abonos recibidos',
    this.saldoPendiente,
    this.nota,
  });

  final NegocioImpreso negocio;
  final String titulo;
  final String numero;
  final DateTime fecha;
  final String? cliente;
  final String? documentoCliente;
  final String? atendidoPor;
  final List<BloqueLineas> bloques;
  final int subtotal;
  final int descuento;
  final int? iva;
  final int total;
  final List<MovimientoDocumento> movimientos;
  final String tituloMovimientos;
  final int? saldoPendiente;
  final String? nota;

  /// `true` si hay que pintar el bloque de abonos.
  bool get tieneMovimientos => movimientos.isNotEmpty;

  /// `true` si el renglón de descuento aporta algo. Un `$0` en un impreso solo
  /// hace ruido.
  bool get tieneDescuento => descuento > 0;

  @override
  List<Object?> get props => [
        negocio,
        titulo,
        numero,
        fecha,
        cliente,
        documentoCliente,
        atendidoPor,
        bloques,
        subtotal,
        descuento,
        iva,
        total,
        movimientos,
        tituloMovimientos,
        saldoPendiente,
        nota,
      ];
}
