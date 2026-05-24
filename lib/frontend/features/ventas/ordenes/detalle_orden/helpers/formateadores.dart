String fmtMoneda(double monto) {
  String valor = monto.abs().toStringAsFixed(2);
  List<String> partes = valor.split('.');
  String entera = partes[0];
  String decimal = partes[1];
  entera = entera.replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
  return "${monto < 0 ? '-' : ''}\$ $entera.$decimal";
}

String fmtFecha(DateTime fecha) {
  final dia  = fecha.day.toString().padLeft(2, '0');
  final mes  = fecha.month.toString().padLeft(2, '0');
  final anio = fecha.year.toString();
  return '$dia/$mes/$anio';
}
