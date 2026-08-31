import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Los tokens de diseño del impreso: colores y estilos de texto.
///
/// Existe por lo mismo que `ColoresApp` y `TipografiaApp`: para que el papel no
/// invente sus propios grises. **Son los valores de `ColoresApp` traducidos a
/// `PdfColor`**, porque el paquete de PDF no entiende `Color` de Flutter y
/// `share/` no puede importar nada de pub.dev.
///
/// Si cambia un color de marca, cambia en los dos sitios. No hay forma de
/// evitarlo sin meter el paquete de PDF dentro de `share/`, que es peor.
abstract final class EstiloPdf {
  // Marca
  static const verde = PdfColor.fromInt(0xFF01B763);
  static const verdeOscuro = PdfColor.fromInt(0xFF005B31);

  // Texto
  static const textoPrincipal = PdfColor.fromInt(0xFF19211D);
  static const textoSecundario = PdfColor.fromInt(0xFF5B6B61);
  static const textoTenue = PdfColor.fromInt(0xFF8A988F);

  // Superficies
  static const fondoEncabezado = PdfColor.fromInt(0xFFFAFBFA);
  static const borde = PdfColor.fromInt(0xFFEAECEA);
  static const bordeFila = PdfColor.fromInt(0xFFF3F5F3);

  // Semánticos: se conservan aunque no sean del verde de marca.
  static const alerta = PdfColor.fromInt(0xFFB45309);

  static pw.TextStyle get nombreNegocio => const pw.TextStyle(
        fontSize: 17,
        fontWeight: pw.FontWeight.bold,
        color: textoPrincipal,
      );

  static pw.TextStyle get datosNegocio =>
      const pw.TextStyle(fontSize: 8.5, color: textoSecundario);

  static pw.TextStyle get tituloDocumento => const pw.TextStyle(
        fontSize: 15,
        fontWeight: pw.FontWeight.bold,
        color: verdeOscuro,
      );

  static pw.TextStyle get numeroDocumento => const pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: textoPrincipal,
      );

  static pw.TextStyle get etiqueta =>
      const pw.TextStyle(fontSize: 8, color: textoTenue);

  static pw.TextStyle get valor =>
      const pw.TextStyle(fontSize: 9.5, color: textoPrincipal);

  static pw.TextStyle get encabezadoTabla => const pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: textoSecundario,
      );

  static pw.TextStyle get celda =>
      const pw.TextStyle(fontSize: 9, color: textoPrincipal);

  static pw.TextStyle get celdaTenue =>
      const pw.TextStyle(fontSize: 7.5, color: textoTenue);

  static pw.TextStyle get tituloGrupo => const pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: verdeOscuro,
      );

  static pw.TextStyle get totalEtiqueta =>
      const pw.TextStyle(fontSize: 9.5, color: textoSecundario);

  static pw.TextStyle get totalValor =>
      const pw.TextStyle(fontSize: 9.5, color: textoPrincipal);

  static pw.TextStyle get granTotalEtiqueta => const pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: textoPrincipal,
      );

  static pw.TextStyle get granTotalValor => const pw.TextStyle(
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
        color: verde,
      );

  static pw.TextStyle get saldoValor => const pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: alerta,
      );

  static pw.TextStyle get pie =>
      const pw.TextStyle(fontSize: 7.5, color: textoTenue);
}
