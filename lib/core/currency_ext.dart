import 'formato.dart';

/// Azúcar sintáctico sobre [formatearPrecio] y [formatearPrecioCompacto].
///
/// No implementa el formato: delega en `formato.dart`, que es la fuente única.
extension CurrencyFormatting on num {
  /// COP completo con separador de miles: 1234567 → $1.234.567
  String toCopString() => formatearPrecio(this);

  /// COP compacto para tarjetas y gráficos: 1500000 → $1.5M
  String toCompactCop() => formatearPrecioCompacto(this);
}
