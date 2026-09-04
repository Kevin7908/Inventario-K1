import 'package:pdf/widgets.dart' as pw;

import '../../../../core/formato.dart';
import '../modelo/bloque_lineas.dart';
import '../modelo/documento_imprimible.dart';
import 'estilo_pdf.dart';
import 'formato_impreso.dart';

/// Las piezas del impreso, cada una por separado.
///
/// Están aquí y no dentro de `ConstructorPdf` para que ese archivo se lea de
/// una sentada: él decide el orden de la hoja, esto pinta cada bloque. Todas
/// reciben el [DocumentoImprimible] ya resuelto y ninguna consulta nada.
///
/// El dinero y las fechas salen de `core/formato.dart`, nunca formateados a
/// mano: el papel tiene que decir el mismo `$28.000` que la pantalla.
///
/// **El formato entra por el constructor**, no por parámetro de cada método:
/// una impresión es de un solo ancho, y pasarlo doce veces solo daría ocasión
/// de pasarlo distinto una vez.
class SeccionesPdf {
  SeccionesPdf(this.formato) : _e = EstiloPdf.de(formato);

  final FormatoImpreso formato;
  final EstiloPdf _e;

  /// Encabezado: logo y datos del taller a la izquierda, tipo y número de
  /// documento a la derecha.
  ///
  /// En una tirilla no hay «izquierda y derecha» que valgan: todo va centrado
  /// y en columna, que es lo único que cabe en 48 mm.
  ///
  /// [logoSvg] llega como texto porque el SVG se lee del bundle una sola vez
  /// y esta función no hace E/S.
  pw.Widget encabezado(DocumentoImprimible doc, String? logoSvg) =>
      formato.esTirilla
          ? _encabezadoTirilla(doc, logoSvg)
          : _encabezadoCarta(doc, logoSvg);

  pw.Widget _encabezadoCarta(DocumentoImprimible doc, String? logoSvg) {
    final negocio = doc.negocio;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logoSvg != null) ...[
          pw.SvgImage(
            svg: logoSvg,
            width: formato.ladoLogo,
            height: formato.ladoLogo,
          ),
          pw.SizedBox(width: 12),
        ],
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(negocio.nombre, style: _e.nombreNegocio),
              if (negocio.lineaUbicacion.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Text(negocio.lineaUbicacion, style: _e.datosNegocio),
              ],
              if (negocio.lineaContacto.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text(negocio.lineaContacto, style: _e.datosNegocio),
              ],
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(doc.titulo, style: _e.tituloDocumento),
            pw.SizedBox(height: 3),
            pw.Text(doc.numero, style: _e.numeroDocumento),
            pw.SizedBox(height: 3),
            pw.Text(formatearFechaHora(doc.fecha), style: _e.datosNegocio),
          ],
        ),
      ],
    );
  }

  pw.Widget _encabezadoTirilla(DocumentoImprimible doc, String? logoSvg) {
    final negocio = doc.negocio;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (logoSvg != null) ...[
          pw.SvgImage(
            svg: logoSvg,
            width: formato.ladoLogo,
            height: formato.ladoLogo,
          ),
          pw.SizedBox(height: 5),
        ],
        pw.Text(
          negocio.nombre,
          style: _e.nombreNegocio,
          textAlign: pw.TextAlign.center,
        ),
        if (negocio.lineaUbicacion.isNotEmpty)
          pw.Text(
            negocio.lineaUbicacion,
            style: _e.datosNegocio,
            textAlign: pw.TextAlign.center,
          ),
        if (negocio.lineaContacto.isNotEmpty)
          pw.Text(
            negocio.lineaContacto,
            style: _e.datosNegocio,
            textAlign: pw.TextAlign.center,
          ),
        pw.SizedBox(height: 7),
        pw.Text(doc.titulo, style: _e.tituloDocumento),
        pw.Text(
          '${doc.numero}  ·  ${formatearFechaHora(doc.fecha)}',
          style: _e.datosNegocio,
        ),
      ],
    );
  }

  /// La franja de «A quién / Atendido por». Se omite entera si el documento no
  /// tiene ninguno de los dos: el mostrador vende sin pedir cédula.
  pw.Widget? destinatario(DocumentoImprimible doc) {
    final tieneCliente = (doc.cliente ?? '').isNotEmpty;
    if (!tieneCliente && (doc.atendidoPor ?? '').isEmpty) return null;

    final quien = [
      ?doc.cliente,
      ?doc.documentoCliente,
    ].where((s) => s.isNotEmpty).join('  ·  ');

    // En la tirilla los dos datos van uno debajo del otro y sin recuadro: la
    // franja de dos columnas dejaría cuatro caracteres por columna.
    if (formato.esTirilla) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: EstiloPdf.borde),
            bottom: pw.BorderSide(color: EstiloPdf.borde),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (tieneCliente)
              pw.Text('${doc.etiquetaDestinatario}: $quien', style: _e.celda),
            if ((doc.atendidoPor ?? '').isNotEmpty)
              pw.Text(
                '${doc.etiquetaAtendidoPor}: ${doc.atendidoPor}',
                style: _e.celdaTenue,
              ),
          ],
        ),
      );
    }

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
            pw.Expanded(child: _campo(doc.etiquetaDestinatario, quien)),
          if ((doc.atendidoPor ?? '').isNotEmpty)
            _campo(doc.etiquetaAtendidoPor, doc.atendidoPor!, alFinal: true),
        ],
      ),
    );
  }

  /// El encabezado de la tabla de líneas. En carta se repite en cada página;
  /// en tirilla se queda en las dos columnas que caben, porque la cantidad y
  /// el precio unitario bajan al segundo renglón de cada línea.
  pw.Widget encabezadoLineas() => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 5),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: EstiloPdf.borde)),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(
              flex: 6,
              child: pw.Text('Descripción', style: _e.encabezadoTabla),
            ),
            if (!formato.esTirilla) ...[
              _celdaDerecha('Cant.', 2, _e.encabezadoTabla),
              _celdaDerecha('V. unitario', 3, _e.encabezadoTabla),
            ],
            _celdaDerecha('Total', 3, _e.encabezadoTabla),
          ],
        ),
      );

  /// Un bloque de líneas con su título. Devuelve varios widgets para que el
  /// `MultiPage` pueda cortar entre líneas si la hoja se acaba.
  List<pw.Widget> bloque(BloqueLineas bloque) {
    if (bloque.vacio) return const [];
    return [
      if (bloque.titulo != null) ...[
        pw.SizedBox(height: 8),
        pw.Text(bloque.titulo!, style: _e.tituloGrupo),
        pw.SizedBox(height: 3),
      ],
      ...bloque.lineas.map(_linea),
    ];
  }

  pw.Widget _linea(LineaDocumento linea) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: EstiloPdf.bordeFila)),
        ),
        child: formato.esTirilla ? _lineaTirilla(linea) : _lineaCarta(linea),
      );

  pw.Widget _lineaCarta(LineaDocumento linea) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(flex: 6, child: _descripcion(linea)),
          _celdaDerecha(formatearCantidad(linea.cantidad), 2, _e.celda),
          _celdaDerecha(formatearPrecio(linea.precioUnitario), 3, _e.celda),
          _celdaDerecha(formatearPrecio(linea.subtotal), 3, _e.celda),
        ],
      );

  /// En dos renglones: qué se llevó arriba, y debajo «2 × $28.000» contra el
  /// total. Es como se lee cualquier tirilla de tienda, y es lo único que cabe
  /// sin partir las palabras.
  pw.Widget _lineaTirilla(LineaDocumento linea) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _descripcion(linea),
          pw.SizedBox(height: 1),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  '${formatearCantidad(linea.cantidad)} × '
                  '${formatearPrecio(linea.precioUnitario)}',
                  style: _e.celdaTenue,
                ),
              ),
              pw.Text(formatearPrecio(linea.subtotal), style: _e.celda),
            ],
          ),
        ],
      );

  pw.Widget _descripcion(LineaDocumento linea) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(linea.descripcion, style: _e.celda),
          if ((linea.referencia ?? '').isNotEmpty)
            pw.Text(linea.referencia!, style: _e.celdaTenue),
        ],
      );

  pw.Widget _campo(String etiqueta, String valor, {bool alFinal = false}) =>
      pw.Column(
        crossAxisAlignment:
            alFinal ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
        children: [
          pw.Text(etiqueta, style: _e.etiqueta),
          pw.SizedBox(height: 2),
          pw.Text(valor, style: _e.valor),
        ],
      );

  pw.Widget _celdaDerecha(String texto, int flex, pw.TextStyle estilo) =>
      pw.Expanded(
        flex: flex,
        child: pw.Text(texto, style: estilo, textAlign: pw.TextAlign.right),
      );
}
