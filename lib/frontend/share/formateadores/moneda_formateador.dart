import 'package:intl/intl.dart';

final _fmt = NumberFormat.currency(
  locale: 'es_CO',
  symbol: '\$',
  decimalDigits: 0,
);

/// Formatea un [double] como pesos colombianos. Ej: 45000 → "$ 45.000"
String fmtMoneda(double valor) => _fmt.format(valor);

/// Convierte texto crudo a COP. Devuelve vacío si no es parseable.
String fmtMonedaDesdeTexto(String texto) {
  final valor = double.tryParse(texto.replaceAll(',', '').replaceAll('.', ''));
  if (valor == null) return '';
  return _fmt.format(valor);
}
