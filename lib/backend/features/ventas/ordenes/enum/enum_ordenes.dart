// Estados válidos de una orden de servicio.
enum EstadoOrden {
  abierta,
  lista,
  entregada,
  anulada;

  // Convierte el valor de la BD (TEXT uppercase) al enum.
  static EstadoOrden desdeTexto(String v) => switch (v.toUpperCase()) {
        'ABIERTA'   => EstadoOrden.abierta,
        'LISTA'     => EstadoOrden.lista,
        'ENTREGADA' => EstadoOrden.entregada,
        'ANULADA'   => EstadoOrden.anulada,
        _           => EstadoOrden.abierta,
      };

  // Valor que se escribe en la BD.
  String get aTexto => name.toUpperCase();

  String get etiqueta => switch (this) {
        EstadoOrden.abierta   => 'Abierta',
        EstadoOrden.lista     => 'Lista',
        EstadoOrden.entregada => 'Entregada',
        EstadoOrden.anulada   => 'Anulada',
      };
}