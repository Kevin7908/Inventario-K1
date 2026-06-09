import '../../../../../backend/features/ventas/ordenes/enum/enum_ordenes.dart';
import '../../../../../backend/features/ventas/ordenes/modelo/orden_resumen.dart';

final class OrdenesState {
  const OrdenesState({
    this.ordenes       = const [],
    this.filtroBusqueda = '',
    this.filtroEstado,
  });

  final List<OrdenResumen> ordenes;
  final String             filtroBusqueda;
  final EstadoOrden?       filtroEstado;

  OrdenesState copyWith({
    List<OrdenResumen>? ordenes,
    String?             filtroBusqueda,
    Object?             filtroEstado = _sentinel,
  }) =>
      OrdenesState(
        ordenes:        ordenes        ?? this.ordenes,
        filtroBusqueda: filtroBusqueda ?? this.filtroBusqueda,
        filtroEstado:   filtroEstado == _sentinel
            ? this.filtroEstado
            : filtroEstado as EstadoOrden?,
      );

  static const Object _sentinel = Object();
}
