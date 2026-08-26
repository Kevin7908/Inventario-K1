/// Por qué el cliente trajo la mercancía de vuelta.
///
/// El [codigo] es lo que viaja a `devoluciones.motivo` y lo que valida su
/// `CHECK`; [etiqueta] es lo que se elige en la pantalla.
///
/// **Ninguno decide si la pieza vuelve a la estantería**: hoy toda devolución
/// repone stock. Que una pieza defectuosa no debería volver a venderse es una
/// decisión de negocio abierta, anotada en `DEUDA_TECNICA.md`.
enum MotivoDevolucion {
  defectuoso('DEFECTUOSO', 'Llegó defectuosa'),
  equivocado('EQUIVOCADO', 'No era la pieza'),
  garantia('GARANTIA', 'Garantía'),
  arrepentimiento('ARREPENTIMIENTO', 'El cliente se arrepintió'),
  errorCaptura('ERROR_CAPTURA', 'Se cobró mal');

  const MotivoDevolucion(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  /// Fragmento `IN (...)` para el `CHECK` de `devoluciones`. Sale del propio
  /// enum para que agregar un motivo no obligue a acordarse de la tabla.
  static String get listaSql => values.map((m) => "'${m.codigo}'").join(', ');

  static MotivoDevolucion desdeCodigo(String codigo) => values.firstWhere(
        (m) => m.codigo == codigo,
        orElse: () => MotivoDevolucion.errorCaptura,
      );
}
