import 'package:intl/intl.dart';

String fmtFechaCorta(DateTime? fecha) {
  if (fecha == null) return '—';
  return DateFormat('dd/MM/yyyy').format(fecha);
}
