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
              if (negocio.lineaFiscal.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text(negocio.lineaFiscal, style: _e.datosNegocio),
              ],
            ],
          ),
        ),
        _tarjetaDocumento(doc),
      ],
    );
  }

  /// El recuadro de la derecha: qué documento es, su número y sus fechas.
  ///
  /// Va en un marco propio porque es lo primero que se busca al tener el papel
  /// en la mano —el número con el que el cliente reclama— y porque separarlo
  /// de los datos del taller evita que las dos columnas se lean como una sola.
  pw.Widget _tarjetaDocumento(DocumentoImprimible doc) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: pw.BoxDecoration(
          color: EstiloPdf.fondoEncabezado,
          border: pw.Border.all(color: EstiloPdf.borde),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(doc.titulo, style: _e.tituloDocumento),
            pw.SizedBox(height: 2),
            pw.Text(doc.numero, style: _e.numeroDocumento),
            pw.SizedBox(height: 6),
            _fechaTarjeta('Emisión', formatearFechaHora(doc.fecha)),
            if (doc.vencimiento != null)
              _fechaTarjeta('Vencimiento', formatearFecha(doc.vencimiento!)),
          ],
        ),
      );

  pw.Widget _fechaTarjeta(String etiqueta, String valor) => pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('$etiqueta  ', style: _e.etiqueta),
          pw.Text(valor, style: _e.datosNegocio),
        ],
      );

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
        for (final linea in [
          negocio.lineaUbicacion,
          negocio.lineaContacto,
          negocio.lineaFiscal,
        ])
          if (linea.isNotEmpty)
            pw.Text(
              linea,
              style: _e.datosNegocio,
              textAlign: pw.TextAlign.center,
            ),
        pw.SizedBox(height: 7),
        pw.Text(doc.titulo, style: _e.tituloDocumento),
        pw.Text(
          '${doc.numero}  ·  ${formatearFechaHora(doc.fecha)}',
          style: _e.datosNegocio,
        ),
        if (doc.vencimiento != null)
          pw.Text(
            'Vence ${formatearFecha(doc.vencimiento!)}',
            style: _e.datosNegocio,
          ),
      ],
    );
  }

  /// La franja de «A quién / Quién atendió». Se omite entera si el documento
  /// no tiene ninguno de los dos: el mostrador vende sin pedir cédula.
  pw.Widget? destinatario(DocumentoImprimible doc) {
    final quien = doc.destinatario;
    final personas = _personas(doc);
    if (quien == null && personas.isEmpty) return null;

    return formato.esTirilla
        ? _destinatarioTirilla(doc, quien, personas)
        : _destinatarioCarta(doc, quien, personas);
  }

  /// Quién despachó el documento, en pares etiqueta/valor.
  ///
  /// El vendedor va aparte de quien lo registró porque responden preguntas
  /// distintas: uno es a quién reclamarle por el trato y el otro es quién lo
  /// tecleó. Cuando son la misma persona, el traductor manda solo uno.
  List<(String, String)> _personas(DocumentoImprimible doc) => [
        if ((doc.atendidoPor ?? '').isNotEmpty)
          (doc.etiquetaAtendidoPor, doc.atendidoPor!),
        if ((doc.vendedor ?? '').isNotEmpty) ('Vendedor', doc.vendedor!),
      ];

  // En la tirilla todo va en renglones de «Etiqueta: valor»: la franja de dos
  // columnas dejaría cuatro caracteres por columna.
  pw.Widget _destinatarioTirilla(
    DocumentoImprimible doc,
    DestinatarioImpreso? quien,
    List<(String, String)> personas,
  ) =>
      pw.Container(
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
            if (quien != null)
              pw.Text(
                '${doc.etiquetaDestinatario}: ${quien.nombre}',
                style: _e.celda,
              ),
            if (quien != null)
              for (final (etiqueta, valor) in quien.campos)
                pw.Text('$etiqueta: $valor', style: _e.celdaTenue),
            for (final (etiqueta, valor) in personas)
              pw.Text('$etiqueta: $valor', style: _e.celdaTenue),
          ],
        ),
      );

  /// En carta la franja son dos columnas: el cliente a la izquierda con sus
  /// datos en renglones, y quién despachó a la derecha.
  pw.Widget _destinatarioCarta(
    DocumentoImprimible doc,
    DestinatarioImpreso? quien,
    List<(String, String)> personas,
  ) =>
      pw.Container(
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
            if (quien != null)
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(doc.etiquetaDestinatario, style: _e.etiqueta),
                    pw.SizedBox(height: 2),
                    pw.Text(quien.nombre, style: _e.valor),
                    for (final (etiqueta, valor) in quien.campos) ...[
                      pw.SizedBox(height: 1),
                      pw.Text('$etiqueta: $valor', style: _e.celdaTenue),
                    ],
                  ],
                ),
              ),
            if (quien != null && personas.isNotEmpty) pw.SizedBox(width: 16),
            if (personas.isNotEmpty)
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    for (final (etiqueta, valor) in personas) ...[
                      pw.Text(etiqueta, style: _e.etiqueta),
                      pw.SizedBox(height: 2),
                      pw.Text(valor, style: _e.valor),
                      pw.SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
          ],
        ),
      );

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
            if (!formato.esTirilla) ...[
              pw.SizedBox(
                width: _anchoItem,
                child: pw.Text('#', style: _e.encabezadoTabla),
              ),
              pw.Expanded(
                flex: 3,
                child: pw.Text('Código', style: _e.encabezadoTabla),
              ),
            ],
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

  /// Ancho de la columna del número de ítem. Fijo porque su contenido no
  /// crece: con tres dígitos ya son más líneas de las que caben en una hoja.
  static const double _anchoItem = 20;

  /// Un bloque de líneas con su título. Devuelve varios widgets para que el
  /// `MultiPage` pueda cortar entre líneas si la hoja se acaba.
  ///
  /// [desde] es el número que le toca a la primera línea del bloque. Se pasa
  /// desde fuera para que la numeración sea **continua a lo largo del
  /// documento**: en una orden con repuestos y mano de obra, el ítem 4 es el
  /// cuarto del papel, no el primero del segundo bloque.
  List<pw.Widget> bloque(BloqueLineas bloque, {int desde = 1}) {
    if (bloque.vacio) return const [];
    return [
      if (bloque.titulo != null) ...[
        pw.SizedBox(height: 8),
        pw.Text(bloque.titulo!, style: _e.tituloGrupo),
        pw.SizedBox(height: 3),
      ],
      for (final (indice, linea) in bloque.lineas.indexed)
        _linea(linea, desde + indice),
    ];
  }

  pw.Widget _linea(LineaDocumento linea, int numero) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: EstiloPdf.bordeFila)),
        ),
        child: formato.esTirilla
            ? _lineaTirilla(linea)
            : _lineaCarta(linea, numero),
      );

  pw.Widget _lineaCarta(LineaDocumento linea, int numero) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: _anchoItem,
            child: pw.Text('$numero', style: _e.celdaTenue),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              linea.tieneCodigo ? linea.codigo! : '—',
              style: _e.celdaCodigo,
            ),
          ),
          pw.Expanded(flex: 6, child: _descripcion(linea)),
          _celdaDerecha(_cantidad(linea), 2, _e.celda),
          _celdaDerecha(formatearPrecio(linea.precioUnitario), 3, _e.celda),
          _celdaDerecha(formatearPrecio(linea.subtotal), 3, _e.celda),
        ],
      );

  /// La cantidad con su unidad: «2 UND». Sin unidad cargada, solo el número.
  String _cantidad(LineaDocumento linea) {
    final cantidad = formatearCantidad(linea.cantidad);
    return linea.unidad.isEmpty ? cantidad : '$cantidad ${linea.unidad}';
  }

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
                  '${_cantidad(linea)} × '
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
          // En carta el código tiene su propia columna, así que aquí solo se
          // repite en tirilla, donde esa columna no cabe.
          if (linea.tieneCodigo && formato.esTirilla)
            pw.Text(linea.codigo!, style: _e.celdaTenue),
          if (linea.tieneDetalle)
            pw.Text(linea.detalle!, style: _e.celdaTenue),
        ],
      );

  pw.Widget _celdaDerecha(String texto, int flex, pw.TextStyle estilo) =>
      pw.Expanded(
        flex: flex,
        child: pw.Text(texto, style: estilo, textAlign: pw.TextAlign.right),
      );
}
