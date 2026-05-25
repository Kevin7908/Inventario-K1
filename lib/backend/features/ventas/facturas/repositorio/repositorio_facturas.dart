import '../enum/enum_facturas.dart';
import '../modelo/factura_detalle.dart';
import '../modelo/factura_resumen.dart';

abstract interface class RepositorioFacturas {
  Stream<List<FacturaResumen>> observarTodas();

  Future<List<FacturaResumen>> obtenerTodas();

  Future<FacturaDetalle> obtenerDetalle(int id);

  Future<FacturaResumen> crear({
    required TipoVenta tipo,
    int? ordenId,
    int? clienteId,
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    double iva,
    double descuento,
  });

  Future<FacturaResumen> crearDesdeOrden({
    required int ordenId,
    required int clienteId,
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    double iva,
  });

  Future<FacturaResumen> actualizar({
    required int id,
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    double? iva,
    double? descuento,
    bool actualizarCliente = false,
    int? clienteId,
  });

  Future<void> eliminar(int id);

  Future<bool> tieneFactura(int ordenId);

  Future<FacturaResumen?> obtenerPorOrden(int ordenId);

  Future<FacturaResumen> actualizarDesdeOrden({
    required int facturaId,
    required int ordenId,
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    double iva,
  });

  // Items (venta_detalles)

  Future<void> agregarItem({
    required int ventaId,
    required TipoItem tipoItem,
    int? productoId,
    int? servicioId,
    int? tecnicoId,
    required String descripcion,
    required double cantidad,
    required double precioUnitario,
    double costoUnitario,
  });

  Future<void> actualizarItem(
    int itemId, {
    double? cantidad,
    double? precioUnitario,
  });

  Future<void> eliminarItem(int itemId);
}
