/// El ciclo de vida de una reserva, **no el de su dinero**.
///
/// Son dos cosas distintas y conviene no mezclarlas: aquí se cuenta dónde está
/// la mercancía —apartada, entregada o devuelta al inventario— y el saldo se
/// deriva de los abonos (`ReservaResumen.pagada`). Se puede deber la mitad de
/// algo ya entregado, y se puede tener pagado del todo algo que sigue en la
/// bodega.
enum EstadoReserva {
  /// Apartada: la mercancía está fuera del inventario disponible, guardada
  /// para este cliente. Es el único estado que admite cambios.
  activa('ACTIVA', 'Activa'),

  /// Entregada: el cliente se llevó lo suyo y la reserva se cierra. **No**
  /// devuelve stock, porque la mercancía salió de verdad.
  completada('COMPLETADA', 'Completada'),

  /// Cancelada: se deshace el apartado y todo vuelve al inventario.
  cancelada('CANCELADA', 'Cancelada');

  const EstadoReserva(this.valor, this.etiqueta);

  /// Lo que va en la base de datos.
  final String valor;

  /// Lo que ve el usuario.
  final String etiqueta;

  /// Si todavía se le pueden mover líneas.
  bool get editable => this == EstadoReserva.activa;

  static EstadoReserva desdeValor(String v) =>
      EstadoReserva.values.firstWhere((e) => e.valor == v);
}
