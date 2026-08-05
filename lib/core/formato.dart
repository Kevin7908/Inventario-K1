import 'package:intl/intl.dart';

/// Formato de números, moneda y fechas de la aplicación.
///
/// **Fuente única.** Antes convivían cuatro implementaciones del separador de
/// miles —dos a mano y dos con `intl`— y podían divergir. Todo lo que muestre
/// dinero o fechas pasa por aquí.
///
/// Localización: Colombia. El peso se muestra sin decimales, con punto como
/// separador de miles y sin espacio tras el símbolo (`$28.000`), que es como
/// aparece en el diseño.
///
/// **Funciona sin internet.** `intl` es Dart puro: los datos de localización
/// van compilados dentro del binario, no se descargan. La única variante que
/// haría red es `date_symbol_data_http_request.dart`, que es solo para web y
/// no se importa aquí.
///
/// **Ojo con `'es_CO'`:** intl no trae datos numéricos para Colombia;
/// `Intl.verifiedLocale` lo resuelve a `'es'`. Da igual para el resultado
/// —español y Colombia comparten el punto como separador de miles— pero no
/// esperar de aquí ningún formato específico de Colombia más allá de eso.

final NumberFormat _enteroCop = NumberFormat('#,##0', 'es_CO');
final NumberFormat _decimalCop = NumberFormat('#,##0.##', 'es_CO');
// Sin locale a propósito: los patrones son puramente numéricos, así que la
// salida no depende del idioma, y pedir 'es_CO' exigiría llamar a
// `initializeDateFormatting` al arrancar solo para esto.
final DateFormat _fecha = DateFormat('dd/MM/yyyy');
final DateFormat _fechaHora = DateFormat('dd/MM/yyyy HH:mm');

/// Pesos colombianos sin decimales: `28000` → `$28.000`.
String formatearPrecio(num valor) => '\$${_enteroCop.format(valor)}';

/// Pesos en formato compacto para tarjetas y gráficos:
/// `1500000` → `$1.5M`, `12000` → `$12K`, `800` → `$800`.
String formatearPrecioCompacto(num valor) {
  if (valor >= 1000000) return '\$${(valor / 1000000).toStringAsFixed(1)}M';
  if (valor >= 1000) return '\$${(valor / 1000).toStringAsFixed(0)}K';
  return formatearPrecio(valor);
}

/// Cantidad con hasta dos decimales, sin ceros de relleno:
/// `12` → `12`, `12.5` → `12,5`.
String formatearCantidad(num valor) => _decimalCop.format(valor);

/// Fecha corta: `04/08/2026`.
String formatearFecha(DateTime fecha) => _fecha.format(fecha);

/// Fecha con hora: `04/08/2026 15:30`.
String formatearFechaHora(DateTime fecha) => _fechaHora.format(fecha);
