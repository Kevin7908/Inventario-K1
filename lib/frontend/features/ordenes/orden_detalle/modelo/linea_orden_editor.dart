/// Qué clase de línea es, y por tanto en qué tabla vive.
///
/// A diferencia de `TipoItemCotizacion`, esto **no se guarda en ninguna
/// columna**: una orden reparte sus líneas en tres tablas distintas
/// (`ordenes_tareas`, `ordenes_repuestos`, `ordenes_cargos`), y cada una tiene
/// lo suyo —la tarea un técnico y un estado de completado, el repuesto una
/// cantidad que mueve stock, el cargo nada de eso—. El enum solo existe para
/// que el editor pueda tratarlas juntas al pintarlas y agruparlas.
///
/// El orden de declaración es el de los bloques del panel derecho: Servicios,
/// Repuestos, Otros cargos.
enum TipoLineaOrden {
  servicio('Servicio', 'Servicios'),
  repuesto('Repuesto', 'Repuestos'),
  cargo('Otro cargo', 'Otros cargos');

  const TipoLineaOrden(this.etiqueta, this.titulo);

  /// Singular, para el selector del panel izquierdo.
  final String etiqueta;

  /// Plural, para el encabezado del bloque en el panel derecho.
  final String titulo;

  /// El orden en que los ofrece el selector del catálogo, que **no** es el de
  /// los bloques: al armar una orden se empieza por los repuestos mucho más a
  /// menudo que por la mano de obra.
  static const List<TipoLineaOrden> ordenCatalogo = [
    repuesto,
    servicio,
    cargo,
  ];

  /// Solo el repuesto tiene cantidad. Una tarea y un cargo son una cosa o no
  /// son: `ordenes_tareas` y `ordenes_cargos` ni siquiera tienen la columna.
  bool get tieneCantidad => this == TipoLineaOrden.repuesto;

  /// Solo el repuesto sale del inventario. Un cargo suelto no mueve stock a
  /// propósito: si el repuesto estuviera en el catálogo, sería un repuesto.
  bool get mueveInventario => this == TipoLineaOrden.repuesto;
}

/// Una línea de la orden tal como está en la base.
///
/// Se diferencia de `ItemCotizacionEditor` en un punto que lo cambia todo:
/// **lleva el `id` de su fila**. El editor de órdenes escribe incremental —una
/// llamada por línea— y sin el id no habría a qué apuntarle un
/// `eliminarRepuesto` o un `actualizarTarea`. En cotizaciones no hacía falta
/// porque `actualizar` reemplaza las líneas enteras.
///
/// [subtotal] es derivado, nunca un campo: guardarlo abriría la puerta a que
/// quedara desfasado de la cantidad y el precio que lo producen.
final class LineaOrdenEditor {
  const LineaOrdenEditor({
    required this.id,
    required this.tipo,
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
    this.referenciaId,
    this.tecnicoId,
    this.tecnicoNombre,
    this.completado = false,
  });

  /// Id de la fila en `ordenes_tareas`, `ordenes_repuestos` u
  /// `ordenes_cargos`, según [tipo].
  final int id;

  final TipoLineaOrden tipo;

  /// Id del servicio o del producto del catálogo. `null` en los cargos, que no
  /// apuntan a nada.
  final int? referenciaId;

  /// Quién hace el trabajo. Solo en las líneas de servicio, donde la columna
  /// es `NOT NULL`: el técnico va por tarea, no por orden.
  final int? tecnicoId;
  final String? tecnicoNombre;

  final String descripcion;

  /// Siempre 1 salvo en los repuestos (ver [TipoLineaOrden.tieneCantidad]).
  final double cantidad;

  final int precioUnitario;

  /// Si la tarea ya se hizo. Solo aplica a los servicios.
  final bool completado;

  int get subtotal => (cantidad * precioUnitario).round();

  LineaOrdenEditor copyWith({
    double? cantidad,
    int? precioUnitario,
    bool? completado,
  }) =>
      LineaOrdenEditor(
        id: id,
        tipo: tipo,
        descripcion: descripcion,
        cantidad: cantidad ?? this.cantidad,
        precioUnitario: precioUnitario ?? this.precioUnitario,
        referenciaId: referenciaId,
        tecnicoId: tecnicoId,
        tecnicoNombre: tecnicoNombre,
        completado: completado ?? this.completado,
      );
}
