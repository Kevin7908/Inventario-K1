import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'formato_impreso.dart';

/// Los tokens de diseño del impreso: colores y estilos de texto.
///
/// Existe por lo mismo que `ColoresApp` y `TipografiaApp`: para que el papel no
/// invente sus propios grises. **Son los valores de `ColoresApp` traducidos a
/// `PdfColor`**, porque el paquete de PDF no entiende `Color` de Flutter y
/// `share/` no puede importar nada de pub.dev.
///
/// Si cambia un color de marca, cambia en los dos sitios. No hay forma de
/// evitarlo sin meter el paquete de PDF dentro de `share/`, que es peor.
///
/// **Los colores son estáticos y los textos no.** Un verde de marca es el
/// mismo en cualquier papel; un cuerpo de 9 pt que se lee bien en carta no
/// cabe en una tirilla de 58 mm, así que cada tamaño se corrige con
/// [FormatoImpreso.ajusteTexto]. Por eso se construye una instancia por
/// impresión —`EstiloPdf.de(formato)`— en vez de tener dos juegos de
/// constantes que habría que mantener a la par.
///
/// Ejemplo:
/// ```dart
/// final estilo = EstiloPdf.de(FormatoImpreso.tirilla80);
/// pw.Text('Total', style: estilo.granTotalEtiqueta);
/// ```
class EstiloPdf {
  const EstiloPdf._(this._ajuste);

  /// Los estilos del formato pedido.
  factory EstiloPdf.de(FormatoImpreso formato) => EstiloPdf._(
        formato.ajusteTexto,
      );

  /// Cuánto se le suma a cada tamaño. Negativo en las tirillas.
  final double _ajuste;

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

  pw.TextStyle _texto(
    double tamano, {
    PdfColor color = textoPrincipal,
    bool negrita = false,
  }) =>
      pw.TextStyle(
        fontSize: tamano + _ajuste,
        fontWeight: negrita ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      );

  pw.TextStyle get nombreNegocio => _texto(17, negrita: true);

  pw.TextStyle get datosNegocio => _texto(8.5, color: textoSecundario);

  pw.TextStyle get tituloDocumento =>
      _texto(15, color: verdeOscuro, negrita: true);

  pw.TextStyle get numeroDocumento => _texto(11, negrita: true);

  pw.TextStyle get etiqueta => _texto(8, color: textoTenue);

  pw.TextStyle get valor => _texto(9.5);

  pw.TextStyle get encabezadoTabla =>
      _texto(8, color: textoSecundario, negrita: true);

  pw.TextStyle get celda => _texto(9);

  pw.TextStyle get celdaTenue => _texto(7.5, color: textoTenue);

  pw.TextStyle get tituloGrupo => _texto(9, color: verdeOscuro, negrita: true);

  pw.TextStyle get totalEtiqueta => _texto(9.5, color: textoSecundario);

  pw.TextStyle get totalValor => _texto(9.5);

  pw.TextStyle get granTotalEtiqueta => _texto(11, negrita: true);

  pw.TextStyle get granTotalValor => _texto(13, color: verde, negrita: true);

  pw.TextStyle get saldoValor => _texto(11, color: alerta, negrita: true);

  pw.TextStyle get pie => _texto(7.5, color: textoTenue);

  /// El encabezado reducido de la segunda página en adelante. Solo lo usa la
  /// carta: una tirilla no tiene páginas que numerar.
  pw.TextStyle get encabezadoContinuacion => _texto(8, color: textoTenue);
}
