import 'deudor_pago.dart';
import 'deudor_resumen.dart';

class DeudorDetalle {
  const DeudorDetalle({
    required this.resumen,
    required this.pagos,
  });

  final DeudorResumen resumen;
  final List<DeudorPago> pagos;
}
