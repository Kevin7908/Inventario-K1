import 'deudor_item.dart';
import 'deudor_pago.dart';
import 'deudor_resumen.dart';

class DeudorDetalle {
  const DeudorDetalle({
    required this.resumen,
    required this.items,
    required this.pagos,
  });

  final DeudorResumen resumen;

  /// Lo fiado, en el orden en que se fue anotando.
  final List<DeudorItem> items;

  final List<DeudorPago> pagos;
}
