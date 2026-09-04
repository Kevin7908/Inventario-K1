import 'package:pdf/widgets.dart' as pw;

import '../../../../core/formato.dart';
import '../modelo/documento_imprimible.dart';
import '../modelo/movimiento_documento.dart';
import 'estilo_pdf.dart';
import 'formato_impreso.dart';

/// El cierre del documento: totales, abonos recibidos y pie de página.
///
/// Separado de `SeccionesPdf` porque responde otra pregunta: aquello pinta
/// **qué se llevó el cliente**, esto pinta **cuánto debe y cuánto ha pagado**.
///
/// La regla del IVA está en `core/iva_app.dart` y aquí solo se obedece: los
/// precios lo llevan incluido, así que el renglón **discrimina** cuánto
/// impuesto va dentro del total, no se lo suma. Por eso dice «incluido» y por
/// eso el total es `subtotal - descuento` sin sumar nada más.
class CierrePdf {
  CierrePdf(this.formato) : _e = EstiloPdf.de(formato);

  final FormatoImpreso formato;
  final EstiloPdf _e;

  /// El bloque de totales. En carta va alineado a la derecha y acotado a
  /// 240 pt para que no se estire por toda la hoja; en tirilla ocupa el ancho
  /// entero, que ya es angosto.
  pw.Widget totales(DocumentoImprimible doc) {
    final cuerpo = pw.Column(
      children: [
        _renglon('Subtotal', formatearPrecio(doc.subtotal)),
        if (doc.tieneDescuento)
          _renglon('Descuento', '- ${formatearPrecio(doc.descuento)}'),
        // Sin el porcentaje a propósito: `etiquetaIva` de `core/iva_app.dart`
        // lo saca de la tasa configurada **hoy**, y una factura de hace un año
        // se cerró con la de entonces. El monto sí es el guardado en el
        // documento, así que «IVA incluido» siempre dice la verdad.
        if (doc.iva != null) _renglon('IVA incluido', formatearPrecio(doc.iva!)),
        pw.SizedBox(height: 5),
        pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: EstiloPdf.borde)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total', style: _e.granTotalEtiqueta),
              pw.Text(formatearPrecio(doc.total), style: _e.granTotalValor),
            ],
          ),
        ),
        if (doc.saldoPendiente != null) ...[
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Saldo pendiente', style: _e.granTotalEtiqueta),
              pw.Text(
                formatearPrecio(doc.saldoPendiente!),
                style: _e.saldoValor,
              ),
            ],
          ),
        ],
      ],
    );

    if (formato.esTirilla) return cuerpo;

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(width: 240, child: cuerpo),
    );
  }

  /// «Cuánto ha abonado, cuándo y de a cuánto»: la tabla de pagos recibidos.
  ///
  /// Devuelve lista vacía si el documento no tiene movimientos, así que quien
  /// lo llame no necesita comprobar nada antes.
  List<pw.Widget> movimientos(DocumentoImprimible doc) {
    if (!doc.tieneMovimientos) return const [];

    final recibido = doc.movimientos.fold<int>(0, (a, m) => a + m.monto);

    return [
      pw.SizedBox(height: formato.esTirilla ? 10 : 18),
      pw.Text(doc.tituloMovimientos, style: _e.tituloGrupo),
      pw.SizedBox(height: 5),
      pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: EstiloPdf.borde)),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(
              flex: 3,
              child: pw.Text('Fecha', style: _e.encabezadoTabla),
            ),
            pw.Expanded(
              flex: 5,
              child: pw.Text('Forma de pago', style: _e.encabezadoTabla),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                'Monto',
                style: _e.encabezadoTabla,
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      ),
      ...doc.movimientos.map(_movimiento),
      // Con un solo renglón el total repetiría la línea de arriba y solo
      // haría ruido; la suma se pinta cuando hay varios que sumar.
      if (doc.movimientos.length > 1) ...[
        pw.SizedBox(height: 5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text('Total abonado  ', style: _e.totalEtiqueta),
            pw.Text(formatearPrecio(recibido), style: _e.numeroDocumento),
          ],
        ),
      ],
    ];
  }

  pw.Widget _movimiento(MovimientoDocumento m) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: EstiloPdf.bordeFila)),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(
              flex: 3,
              child: pw.Text(formatearFecha(m.fecha), style: _e.celda),
            ),
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    // Una devolución no es un abono, y el papel tiene que
                    // decirlo: si no, la suma de la columna no cuadra con
                    // los renglones.
                    m.esDevolucion ? '${m.concepto} (devolución)' : m.concepto,
                    style: _e.celda,
                  ),
                  if ((m.referencia ?? '').isNotEmpty)
                    pw.Text(m.referencia!, style: _e.celdaTenue),
                ],
              ),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                formatearPrecio(m.monto),
                style: _e.celda,
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      );

  /// El pie de cada página: la nota del documento, la numeración y el nombre
  /// de la aplicación, que es lo que pidió el taller que apareciera al final.
  ///
  /// La numeración solo aparece en carta. Una tirilla no tiene páginas —el
  /// rollo crece hasta donde llegue el texto—, así que ahí el pie es la nota
  /// centrada y nada más.
  pw.Widget pie(DocumentoImprimible doc, int pagina, int de) {
    final nota = (doc.nota ?? '').trim();

    if (formato.esTirilla) {
      return pw.Container(
        padding: const pw.EdgeInsets.only(top: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: EstiloPdf.borde)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (nota.isNotEmpty)
              pw.Text(nota, style: _e.pie, textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 3),
            pw.Text('InventarioK1', style: _e.pie),
          ],
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: EstiloPdf.borde)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(child: pw.Text(nota, style: _e.pie)),
          pw.Text(
            de > 1 ? 'Página $pagina de $de  ·  InventarioK1' : 'InventarioK1',
            style: _e.pie,
          ),
        ],
      ),
    );
  }

  pw.Widget _renglon(String etiqueta, String valor) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(etiqueta, style: _e.totalEtiqueta),
            pw.Text(valor, style: _e.totalValor),
          ],
        ),
      );
}
