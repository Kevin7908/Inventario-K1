import 'package:equatable/equatable.dart';

import 'movimiento_inventario.dart';

/// Un renglón del libro mayor **con lo que hace falta para leerlo**: qué
/// producto era y quién lo movió.
///
/// [MovimientoInventario] guarda ids porque es lo que hay en la tabla; esto es
/// lo que pinta la pantalla, con los `JOIN` ya resueltos en SQL. Se separan
/// para no obligar a la ficha de un producto —que ya sabe de qué producto
/// habla— a cargar el nombre en cada fila.
final class MovimientoDetalle extends Equatable {
  const MovimientoDetalle({
    required this.movimiento,
    required this.productoNombre,
    required this.productoSku,
    required this.usuario,
    this.numeroDocumento,
  });

  final MovimientoInventario movimiento;

  /// Del `JOIN` con `productos`. Es el nombre de **hoy**, no un snapshot: el
  /// libro mayor apunta al catálogo y el catálogo no se borra (FK `restrict`).
  final String productoNombre;
  final String productoSku;

  /// Quién lo registró, del `JOIN` con `usuarios` y `personas`.
  final String usuario;

  /// El número del documento que lo causó —`FAC-0012`, `ORD-0041`…— cuando lo
  /// hay. Un ajuste manual no tiene documento y llega en `null`.
  final String? numeroDocumento;

  int get id => movimiento.id;
  TipoMovimiento get tipo => movimiento.tipo;
  double get cantidad => movimiento.cantidad;
  bool get entra => movimiento.entra;
  DateTime get creadoEn => movimiento.creadoEn;
  String? get notas => movimiento.notas;

  @override
  List<Object?> get props =>
      [movimiento, productoNombre, productoSku, usuario, numeroDocumento];
}
