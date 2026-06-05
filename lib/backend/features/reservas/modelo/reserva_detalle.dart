import 'reserva_abono.dart';
import 'reserva_item.dart';
import 'reserva_resumen.dart';

class ReservaDetalle {
  const ReservaDetalle({
    required this.resumen,
    required this.items,
    required this.abonos,
  });

  final ReservaResumen resumen;
  final List<ReservaItem> items;
  final List<ReservaAbono> abonos;
}
