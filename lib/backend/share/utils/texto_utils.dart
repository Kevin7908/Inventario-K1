/// Cómo se compara el texto que escribe una persona con el que hay guardado.
///
/// Vive aparte de `sku_utils.dart` porque lo comparten dos cosas que no
/// tienen nada que ver entre sí: el prefijo del SKU —que sale del nombre de
/// la categoría— y el buscador del catálogo. Tener el mapa de tildes dos
/// veces era la forma de que un día dejaran de coincidir.
library;

/// Las letras con tilde y su equivalente sin ella, en minúscula.
///
/// La `ñ` entra: en un teclado se escribe fácil, pero el catálogo lo teclea
/// quien recibe la mercancía y «Piñones» aparece escrito «Piniones» y
/// «Pinones» con la misma naturalidad.
const Map<String, String> tildes = {
  'á': 'a',
  'é': 'e',
  'í': 'i',
  'ó': 'o',
  'ú': 'u',
  'ü': 'u',
  'ñ': 'n',
};

/// El texto en minúsculas y sin tildes, que es como se compara.
///
/// Ejemplo:
/// ```dart
/// aplanarTexto('Baterías Yamaha');  // 'baterias yamaha'
/// ```
String aplanarTexto(String texto) {
  final minusculas = texto.toLowerCase();
  final buffer = StringBuffer();
  for (final caracter in minusculas.split('')) {
    buffer.write(tildes[caracter] ?? caracter);
  }
  return buffer.toString();
}
