import '../../../core/formato.dart';

/// Formateo de moneda para los módulos legacy.
///
/// Delega en `core/formato.dart`, la fuente única. No agregar formato aquí.

/// Formatea un [double] como pesos colombianos. Ej: 45000 → "$45.000"
/// Acepta `num` porque los precios del catálogo ya son `int` (pesos enteros)
/// y los de ventas todavía son `double`. Cuando ventas migre, quedará `int`.
String fmtMoneda(num valor) => formatearPrecio(valor);

/// Convierte texto crudo a COP. Devuelve vacío si no es parseable.
String fmtMonedaDesdeTexto(String texto) {
  final valor = double.tryParse(texto.replaceAll(',', '').replaceAll('.', ''));
  if (valor == null) return '';
  return formatearPrecio(valor);
}
