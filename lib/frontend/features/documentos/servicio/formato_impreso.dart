import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// En qué papel sale el documento.
///
/// Son **el mismo documento en dos anchos**, no dos plantillas: `SeccionesPdf`
/// y `CierrePdf` reciben el formato y acomodan las columnas. Con dos
/// plantillas, la letra pequeña de la factura de carta y la de la tirilla
/// empezarían a divergir el mismo día, que es justo lo que
/// `DocumentoImprimible` existe para evitar.
///
/// La diferencia de fondo no es el ancho sino el **alto**: una hoja de carta
/// se acaba y hay que pasar a la siguiente —de ahí el `MultiPage` con su
/// encabezado repetido y su «Página 2 de 3»—, mientras que un rollo térmico no
/// se acaba nunca. Por eso [esTirilla] decide también con qué widget de página
/// se arma el PDF, y por eso una tirilla no tiene numeración de páginas: no
/// hay páginas que numerar.
///
/// El ancho útil manda sobre todo lo demás: en 58 mm quedan unos 48 mm
/// imprimibles, donde no caben cuatro columnas. Ahí la línea se parte en dos
/// renglones —qué, y luego cantidad × precio contra el total—, que es como se
/// lee cualquier tirilla de tienda.
enum FormatoImpreso {
  /// Carta, la hoja de oficina. Es lo que se entrega con la moto.
  carta('Carta'),

  /// Tirilla de 80 mm, la impresora térmica ancha del mostrador.
  tirilla80('Tirilla 80 mm'),

  /// Tirilla de 58 mm, la angosta.
  tirilla58('Tirilla 58 mm');

  const FormatoImpreso(this.etiqueta);

  /// Lo que se lee en el selector.
  final String etiqueta;

  /// Lo que viaja a la tabla `configuracion`. Es el nombre del valor en
  /// MAYÚSCULAS, como todo enum guardado (`REGLAS_BD.md` §2).
  String get codigo => name.toUpperCase();

  /// `true` si es un rollo continuo. Decide el widget de página, los márgenes
  /// y si la línea se parte en dos renglones.
  bool get esTirilla => this != FormatoImpreso.carta;

  /// El papel. `roll80` y `roll57` tienen **alto infinito**: el paquete de PDF
  /// lo reemplaza por el alto real del contenido al maquetar, que es lo que
  /// hace que la térmica corte donde termina el texto y no tres metros
  /// después.
  PdfPageFormat get pagina => switch (this) {
        FormatoImpreso.carta => PdfPageFormat.letter,
        FormatoImpreso.tirilla80 => PdfPageFormat.roll80,
        FormatoImpreso.tirilla58 => PdfPageFormat.roll57,
      };

  /// Los márgenes. En una tirilla son mínimos: cada milímetro de margen es
  /// un milímetro menos de descripción.
  pw.EdgeInsets get margen => switch (this) {
        FormatoImpreso.carta =>
          const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        _ => const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      };

  /// Cuánto mide el logo del encabezado. En 58 mm ocuparía un tercio del
  /// ancho, así que se achica.
  double get ladoLogo => switch (this) {
        FormatoImpreso.carta => 42,
        FormatoImpreso.tirilla80 => 30,
        FormatoImpreso.tirilla58 => 26,
      };

  /// Cuánto se le quita a cada tamaño de letra. En una tirilla el ancho útil
  /// es un tercio, así que la misma escala tipográfica no cabe.
  double get ajusteTexto => switch (this) {
        FormatoImpreso.carta => 0,
        FormatoImpreso.tirilla80 => -0.5,
        FormatoImpreso.tirilla58 => -1,
      };

  static FormatoImpreso desdeCodigo(String codigo) => values.firstWhere(
        (f) => f.codigo == codigo.trim().toUpperCase(),
        // Un valor que nadie reconoce no puede dejar sin imprimir: la carta es
        // el papel que todo taller tiene.
        orElse: () => FormatoImpreso.carta,
      );
}
