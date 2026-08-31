import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../modelo/documento_imprimible.dart';
import 'cierre_pdf.dart';
import 'secciones_pdf.dart';

/// Convierte un [DocumentoImprimible] en los bytes de un PDF.
///
/// **Es el único sitio del proyecto que arma un impreso.** El punto de venta,
/// las reservas, las cotizaciones y las órdenes pasan todas por aquí: cada
/// módulo traduce su modelo a [DocumentoImprimible] y esta clase pinta. Así la
/// factura y la reserva no pueden divergir en márgenes, tipografía ni en el
/// orden de los totales.
///
/// No conoce ventas ni reservas: si un `import` de este archivo apunta a un
/// módulo de negocio, algo se hizo mal.
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

  /// El SVG ya leído. Se guarda porque el bundle es E/S y una caja imprime
  /// muchas facturas por turno; el archivo no cambia mientras corre la app.
  static String? _logoCacheado;

  Future<Uint8List> construir(DocumentoImprimible doc) async {
    final logo = await _logo();
    final documento = pw.Document(
      title: '${doc.titulo} ${doc.numero}',
      author: doc.negocio.nombre,
      creator: 'InventarioK1',
    );

    documento.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          pageFormat: PdfPageFormat.letter,
          margin: pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
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
                  style: EstiloEncabezadoContinuacion.estilo,
                ),
              ),
        footer: (contexto) =>
            CierrePdf.pie(doc, contexto.pageNumber, contexto.pagesCount),
        build: (contexto) => [
          // El encabezado grande va sin condición de página: `build` arma un
          // flujo continuo y `MultiPage` lo corta solo, así que esto cae en la
          // primera hoja por ser lo primero. Preguntar aquí por
          // `contexto.pageNumber` **lanza**: las páginas todavía no existen
          // cuando este callback corre. De la segunda en adelante se encarga
          // `header`, que sí tiene número de página.
          SeccionesPdf.encabezado(doc, logo),
          pw.SizedBox(height: 18),
          ?SeccionesPdf.destinatario(doc),
          pw.SizedBox(height: 14),
          SeccionesPdf.encabezadoLineas(),
          for (final bloque in doc.bloques) ...SeccionesPdf.bloque(bloque),
          pw.SizedBox(height: 14),
          CierrePdf.totales(doc),
          ...CierrePdf.movimientos(doc),
        ],
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
}

/// Estilo del encabezado reducido de la segunda página en adelante.
abstract final class EstiloEncabezadoContinuacion {
  static pw.TextStyle get estilo => const pw.TextStyle(
        fontSize: 8,
        color: PdfColor.fromInt(0xFF8A988F),
      );
}
