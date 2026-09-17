/// Por qué el cliente trajo la mercancía de vuelta.
///
/// El [codigo] es lo que viaja a `devoluciones.motivo` y lo que valida su
/// `CHECK`; [etiqueta] es lo que se elige en la pantalla.
///
/// **El motivo propone si la pieza vuelve a la estantería, no lo decide.** Una
/// pastilla que llegó rota no se vuelve a vender: se le reclama al proveedor.
/// Pero «defectuosa» es lo que dijo el cliente, y a veces la pieza está bien,
/// así que quien recibe puede cambiarlo. Lo que manda es
/// `devoluciones.reingresa_stock`; esto solo pone el interruptor donde suele
/// ir (ver [reponeStockPorDefecto]).
enum MotivoDevolucion {
  defectuoso('DEFECTUOSO', 'Llegó defectuosa'),
  equivocado('EQUIVOCADO', 'No era la pieza'),
  garantia('GARANTIA', 'Garantía'),
  arrepentimiento('ARREPENTIMIENTO', 'El cliente se arrepintió'),
  errorCaptura('ERROR_CAPTURA', 'Se cobró mal');

  const MotivoDevolucion(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  /// Si con este motivo la mercancía suele volver al estante.
  ///
  /// Falso en los dos que hablan de una pieza que no sirve —[defectuoso] y
  /// [garantia]—: ésas se le reclaman al proveedor, no se vuelven a vender.
  /// En los otros tres la pieza está bien y lo que cambió fue de opinión el
  /// cliente, o la cuenta.
  ///
  /// **Es un valor por defecto, no una regla**: la decisión viaja en la
  /// columna `reingresa_stock` de cada devolución.
  bool get reponeStockPorDefecto => switch (this) {
        MotivoDevolucion.defectuoso || MotivoDevolucion.garantia => false,
        MotivoDevolucion.equivocado ||
        MotivoDevolucion.arrepentimiento ||
        MotivoDevolucion.errorCaptura =>
          true,
      };

  /// Fragmento `IN (...)` para el `CHECK` de `devoluciones`. Sale del propio
  /// enum para que agregar un motivo no obligue a acordarse de la tabla.
  static String get listaSql => values.map((m) => "'${m.codigo}'").join(', ');

  static MotivoDevolucion desdeCodigo(String codigo) => values.firstWhere(
        (m) => m.codigo == codigo,
        orElse: () => MotivoDevolucion.errorCaptura,
      );
}
