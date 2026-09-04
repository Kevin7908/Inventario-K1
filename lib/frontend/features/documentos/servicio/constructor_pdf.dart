import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

import '../modelo/documento_imprimible.dart';
import 'cierre_pdf.dart';
import 'estilo_pdf.dart';
import 'formato_impreso.dart';
import 'secciones_pdf.dart';

/// Convierte un [DocumentoImprimible] en los bytes de un PDF.
///
/// **Es el único sitio del proyecto que arma un impreso.** El punto de venta,
/// las reservas, las cotizaciones, las órdenes, las deudas y las compras pasan
/// todas por aquí: cada módulo traduce su modelo a [DocumentoImprimible] y esta
/// clase pinta. Así la factura y la reserva no pueden divergir en márgenes,
/// tipografía ni en el orden de los totales.
///
/// No conoce ventas ni reservas: si un `import` de este archivo apunta a un
/// módulo de negocio, algo se hizo mal.
///
/// El [FormatoImpreso] decide el ancho y, con él, **el widget de página**: la
/// carta es un `MultiPage` que corta en hojas y repite encabezado y pie, y la
/// tirilla es una `Page` sobre un rollo de alto infinito, que el paquete
/// reemplaza por el alto real del contenido. Un `MultiPage` no sirve para el
/// rollo —tiene un `assert` contra el alto infinito— y una `Page` no sirve
/// para la carta, porque una factura larga se saldría de la hoja.
///
/// Ejemplo:
/// ```dart
/// final bytes = await const ConstructorPdf().construir(documento);
/// await Printing.layoutPdf(onLayout: (_) => bytes);
/// ```
class ConstructorPdf {
  const ConstructorPdf();

  /// Ruta del logo. Es el mismo SVG que pinta `LogoSidebar`, no una copia.
  static const rutaLogo = 'assets/images/logo-k1.svg';

  /// Las dos caras de la tipografía del impreso.
  ///
  /// **No son la fuente de la interfaz.** El paquete de PDF solo trae
  /// Helvetica, que no tiene Unicode: con ella, cualquier carácter fuera de
  /// Latin-1 saldría mal en un papel que el taller entrega. Noto Sans va
  /// empaquetada en `assets/fonts/` con su licencia OFL.
  static const rutaFuente = 'assets/fonts/NotoSans-Regular.ttf';
  static const rutaFuenteNegrita = 'assets/fonts/NotoSans-Bold.ttf';

  /// El SVG ya leído. Se guarda porque el bundle es E/S y una caja imprime
  /// muchas facturas por turno; el archivo no cambia mientras corre la app.
  static String? _logoCacheado;

  /// Las fuentes ya parseadas, por lo mismo: son medio mega cada una y
  /// volverlas a leer en cada impresión se nota en el mostrador.
  static pw.ThemeData? _temaCacheado;

  Future<Uint8List> construir(
    DocumentoImprimible doc, {
    FormatoImpreso formato = FormatoImpreso.carta,
  }) async {
    final logo = await _logo();
    final tema = await _tema();
    final secciones = SeccionesPdf(formato);
    final cierre = CierrePdf(formato);

    final documento = pw.Document(
      title: '${doc.titulo} ${doc.numero}',
      author: doc.negocio.nombre,
      creator: 'InventarioK1',
    );

    // El cuerpo es el mismo en los dos formatos: lo que cambia es dónde se
    // corta. Se arma una sola vez para que no haya forma de que una hoja
    // lleve algo que la tirilla no.
    List<pw.Widget> cuerpo() => [
          secciones.encabezado(doc, logo),
          pw.SizedBox(height: formato.esTirilla ? 10 : 18),
          ?secciones.destinatario(doc),
          pw.SizedBox(height: formato.esTirilla ? 8 : 14),
          secciones.encabezadoLineas(),
          for (final bloque in doc.bloques) ...secciones.bloque(bloque),
          pw.SizedBox(height: formato.esTirilla ? 8 : 14),
          cierre.totales(doc),
          ...cierre.movimientos(doc),
        ];

    if (formato.esTirilla) {
      documento.addPage(
        pw.Page(
          pageTheme: pw.PageTheme(
            pageFormat: formato.pagina,
            margin: formato.margen,
            theme: tema,
          ),
          build: (contexto) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              ...cuerpo(),
              pw.SizedBox(height: 10),
              // En la tirilla el pie va dentro del cuerpo porque no hay
              // páginas: `Page` no tiene `footer`, y tampoco hace falta —el
              // rollo termina donde termina el texto—.
              cierre.pie(doc, 1, 1),
            ],
          ),
        ),
      );
      return documento.save();
    }

    documento.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: formato.pagina,
          margin: formato.margen,
          theme: tema,
        ),
        header: (contexto) => contexto.pageNumber == 1
            ? pw.SizedBox.shrink()
            // A partir de la segunda hoja el encabezado se repite en
            // pequeño: si una factura larga se separa, cada página tiene
            // que poder identificarse sola.
            : pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  '${doc.negocio.nombre}  ·  ${doc.titulo} ${doc.numero}',
                  style: EstiloPdf.de(formato).encabezadoContinuacion,
                ),
              ),
        footer: (contexto) =>
            cierre.pie(doc, contexto.pageNumber, contexto.pagesCount),
        // El encabezado grande va sin condición de página: `build` arma un
        // flujo continuo y `MultiPage` lo corta solo, así que esto cae en la
        // primera hoja por ser lo primero. Preguntar aquí por
        // `contexto.pageNumber` **lanza**: las páginas todavía no existen
        // cuando este callback corre. De la segunda en adelante se encarga
        // `header`, que sí tiene número de página.
        build: (contexto) => cuerpo(),
      ),
    );

    return documento.save();
  }

  Future<String?> _logo() async {
    if (_logoCacheado != null) return _logoCacheado;
    try {
      return _logoCacheado = await rootBundle.loadString(rutaLogo);
    } catch (_) {
      // Un logo que no carga no puede impedir que se entregue la factura: el
      // impreso sale sin él y el taller se entera por el hueco, no por una
      // excepción en el mostrador.
      return null;
    }
  }

  /// El tema con Noto Sans, o `null` para que el paquete caiga en Helvetica.
  ///
  /// Vale la misma regla que el logo: si el asset no está, el papel sale igual
  /// —con la limitación de Latin-1 que había antes— en vez de reventar en la
  /// caja.
  Future<pw.ThemeData?> _tema() async {
    if (_temaCacheado != null) return _temaCacheado;
    try {
      final regular = pw.Font.ttf(await rootBundle.load(rutaFuente));
      final negrita = pw.Font.ttf(await rootBundle.load(rutaFuenteNegrita));
      return _temaCacheado = pw.ThemeData.withFont(
        base: regular,
        bold: negrita,
        // Sin cursiva empaquetada: ningún estilo del impreso la usa, y son
        // otro medio mega en el instalador. El paquete cae en la regular.
        italic: regular,
        boldItalic: negrita,
      );
    } catch (_) {
      return null;
    }
  }
}
