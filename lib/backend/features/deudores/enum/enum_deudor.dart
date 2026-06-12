enum EstadoDeudor {
  activa('ACTIVA'),
  pagada('PAGADA'),
  incobrable('INCOBRABLE'),
  vencida('VENCIDA');

  const EstadoDeudor(this.valor);
  final String valor;

  static EstadoDeudor desdeValor(String v) =>
      EstadoDeudor.values.firstWhere((e) => e.valor == v);
}

const List<String> kMetodosPagoDeudor = [
  'Efectivo',
  'Transferencia',
  'Tarjeta',
  'Nequi',
  'Daviplata',
];
