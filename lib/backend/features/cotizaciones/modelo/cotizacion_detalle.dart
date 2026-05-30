import 'cotizacion_item.dart';
import 'cotizacion_resumen.dart';

class CotizacionDetalle {
  final CotizacionResumen resumen;
  final List<CotizacionItem> items;

  const CotizacionDetalle({required this.resumen, required this.items});
}
