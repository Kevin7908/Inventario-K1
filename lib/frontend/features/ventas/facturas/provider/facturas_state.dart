import '../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../../../../backend/features/ventas/facturas/modelo/factura_resumen.dart';

final class FacturasState {
  const FacturasState({
    this.facturas        = const [],
    this.filtroBusqueda  = '',
    this.filtroEstadoPago,
  });

  final List<FacturaResumen> facturas;
  final String               filtroBusqueda;
  final EstadoPago?          filtroEstadoPago;

  FacturasState copyWith({
    List<FacturaResumen>? facturas,
    String?               filtroBusqueda,
    Object?               filtroEstadoPago = _sentinel,
  }) =>
      FacturasState(
        facturas:        facturas        ?? this.facturas,
        filtroBusqueda:  filtroBusqueda  ?? this.filtroBusqueda,
        filtroEstadoPago: filtroEstadoPago == _sentinel
            ? this.filtroEstadoPago
            : filtroEstadoPago as EstadoPago?,
      );

  static const Object _sentinel = Object();
}
