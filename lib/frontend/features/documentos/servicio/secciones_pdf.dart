import 'package:pdf/widgets.dart' as pw;

import '../../../../core/formato.dart';
import '../modelo/bloque_lineas.dart';
import '../modelo/documento_imprimible.dart';
import 'estilo_pdf.dart';

/// Las piezas del impreso, cada una por separado.
///
/// Están aquí y no dentro de `ConstructorPdf` para que ese archivo se lea de
/// una sentada: él decide el orden de la hoja, esto pinta cada bloque. Todas
/// reciben el [DocumentoImprimible] ya resuelto y ninguna consulta nada.
///
/// El dinero y las fechas salen de `core/formato.dart`, nunca formateados a
/// mano: el papel tiene que decir el mismo `$28.000` que la pantalla.
abstract final class SeccionesPdf {
  /// Encabezado: logo y datos del taller a la izquierda, tipo y número de
  /// documento a la derecha.
  ///
  /// [logoSvg] llega como texto porque el SVG se lee del bundle una sola vez
  /// y esta función no hace E/S.
  static pw.Widget encabezado(DocumentoImprimible doc, String? logoSvg) {
    final negocio = doc.negocio;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logoSvg != null) ...[
          pw.SvgImage(svg: logoSvg, width: 42, height: 42),
          pw.SizedBox(width: 12),
        ],
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(negocio.nombre, style: EstiloPdf.nombreNegocio),
              if (negocio.lineaUbicacion.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Text(negocio.lineaUbicacion,
                    style: EstiloPdf.datosNegocio),
              ],
              if (negocio.lineaContacto.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text(negocio.lineaContacto, style: EstiloPdf.datosNegocio),
              ],
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(doc.titulo, style: EstiloPdf.tituloDocumento),
            pw.SizedBox(height: 3),
            pw.Text(doc.numero, style: EstiloPdf.numeroDocumento),
            pw.SizedBox(height: 3),
            pw.Text(formatearFechaHora(doc.fecha),
                style: EstiloPdf.datosNegocio),
          ],
        ),
      ],
    );
  }

  /// La franja de «A quién / Atendido por». Se omite entera si el documento no
  /// tiene ninguno de los dos: el mostrador vende sin pedir cédula.
  static pw.Widget? destinatario(DocumentoImprimible doc) {
    final tieneCliente = (doc.cliente ?? '').isNotEmpty;
    if (!tieneCliente && (doc.atendidoPor ?? '').isEmpty) return null;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const pw.BoxDecoration(
        color: EstiloPdf.fondoEncabezado,
        border: pw.Border(
          top: pw.BorderSide(color: EstiloPdf.borde),
          bottom: pw.BorderSide(color: EstiloPdf.borde),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (tieneCliente)
            pw.Expanded(
              child: _campo(
                'Cliente',
                [doc.cliente!, if (doc.documentoCliente != null) doc.documentoCliente!]
                    .where((s) => s.isNotEmpty)
                    .join('  ·  '),
              ),
            ),
          if ((doc.atendidoPor ?? '').isNotEmpty)
            _campo('Atendido por', doc.atendidoPor!, alFinal: true),
        ],
      ),
    );
  }

  /// El encabezado de la tabla de líneas. Se repite en cada página.
  static pw.Widget encabezadoLineas() => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 5),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: EstiloPdf.borde)),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(
              flex: 6,
              child: pw.Text('Descripción',
                  style: EstiloPdf.encabezadoTabla),
            ),
            _celdaDerecha('Cant.', 2, EstiloPdf.encabezadoTabla),
            _celdaDerecha('V. unitario', 3, EstiloPdf.encabezadoTabla),
            _celdaDerecha('Total', 3, EstiloPdf.encabezadoTabla),
          ],
        ),
      );

  /// Un bloque de líneas con su título. Devuelve varios widgets para que el
  /// `MultiPage` pueda cortar entre líneas si la hoja se acaba.
  static List<pw.Widget> bloque(BloqueLineas bloque) {
    if (bloque.vacio) return const [];
    return [
      if (bloque.titulo != null) ...[
        pw.SizedBox(height: 8),
        pw.Text(bloque.titulo!, style: EstiloPdf.tituloGrupo),
        pw.SizedBox(height: 3),
      ],
      ...bloque.lineas.map(_linea),
    ];
  }

  static pw.Widget _linea(LineaDocumento linea) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: EstiloPdf.bordeFila)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 6,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(linea.descripcion, style: EstiloPdf.celda),
                  if ((linea.referencia ?? '').isNotEmpty)
                    pw.Text(linea.referencia!, style: EstiloPdf.celdaTenue),
                ],
              ),
            ),
            _celdaDerecha(
                formatearCantidad(linea.cantidad), 2, EstiloPdf.celda),
            _celdaDerecha(
                formatearPrecio(linea.precioUnitario), 3, EstiloPdf.celda),
            _celdaDerecha(formatearPrecio(linea.subtotal), 3, EstiloPdf.celda),
          ],
        ),
      );

  static pw.Widget _campo(String etiqueta, String valor,
          {bool alFinal = false}) =>
      pw.Column(
        crossAxisAlignment:
            alFinal ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
        children: [
          pw.Text(etiqueta, style: EstiloPdf.etiqueta),
          pw.SizedBox(height: 2),
          pw.Text(valor, style: EstiloPdf.valor),
        ],
      );

  static pw.Widget _celdaDerecha(String texto, int flex, pw.TextStyle estilo) =>
      pw.Expanded(
        flex: flex,
        child: pw.Text(texto, style: estilo, textAlign: pw.TextAlign.right),
      );
}
