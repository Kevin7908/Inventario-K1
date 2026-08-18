enum EstadoReserva {
  activa('ACTIVA'),
  completada('COMPLETADA'),
  cancelada('CANCELADA');

  const EstadoReserva(this.valor);
  final String valor;

  static EstadoReserva desdeValor(String v) =>
      EstadoReserva.values.firstWhere((e) => e.valor == v);
}
