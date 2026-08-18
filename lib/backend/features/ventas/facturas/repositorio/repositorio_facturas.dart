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
    int iva,
    int descuento,
  });

  Future<FacturaResumen> crearDesdeOrden({
    required int ordenId,
    required int clienteId,
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    int iva,
  });

  Future<FacturaResumen> actualizar({
    required int id,
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    int? iva,
    int? descuento,
    bool actualizarCliente = false,
    int? clienteId,
  });

  /// Anula la factura y devuelve el stock que había salido.
  ///
  /// **No la borra**: una factura es un documento contable, y borrarla dejaría
  /// huecos en el consecutivo y salidas de inventario sin documento que las
  /// explique. Queda en `ANULADA`, con su número. La base lo refuerza: hay una
  /// guarda que rechaza cualquier `DELETE` sobre `ventas`.
  ///
  /// Lanza si la factura no existe o si ya estaba anulada.
  Future<void> anular(int id);

  Future<bool> tieneFactura(int ordenId);

  Future<FacturaResumen?> obtenerPorOrden(int ordenId);

  Future<FacturaResumen> actualizarDesdeOrden({
    required int facturaId,
    required int ordenId,
    int? clienteId,
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    int iva,
    int descuento,
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
    required int precioUnitario,
    int costoUnitario,
  });

  Future<void> actualizarItem(
    int itemId, {
    double? cantidad,
    int? precioUnitario,
  });

  Future<void> eliminarItem(int itemId);

  Future<FacturaResumen> actualizarPago({
    required int id,
    required int totalPagado,
    required EstadoPago estadoPago,
    required MetodoPago metodoPago,
  });
}
