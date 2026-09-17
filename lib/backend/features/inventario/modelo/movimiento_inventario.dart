import 'package:equatable/equatable.dart';

/// Por qué se movió el stock.
///
/// El [codigo] es lo que viaja a `movimientos_inventario.tipo` y lo que valida
/// su `CHECK`; [etiqueta] es lo que ve el usuario en el historial.
enum TipoMovimiento {
  ajusteInicial('AJUSTE_INICIAL', 'Stock inicial'),
  ajustePositivo('AJUSTE_POSITIVO', 'Ajuste (entrada)'),
  ajusteNegativo('AJUSTE_NEGATIVO', 'Ajuste (salida)'),
  entradaCompra('ENTRADA_COMPRA', 'Compra a proveedor'),
  salidaVenta('SALIDA_VENTA', 'Venta'),
  salidaServicio('SALIDA_SERVICIO', 'Repuesto de orden'),
  salidaReserva('SALIDA_RESERVA', 'Reserva'),
  salidaFiado('SALIDA_FIADO', 'Fiado'),
  devolucionVenta('DEVOLUCION_VENTA', 'Venta anulada'),
  devolucionServicio('DEVOLUCION_SERVICIO', 'Repuesto retirado de la orden'),
  devolucionReserva('DEVOLUCION_RESERVA', 'Reserva liberada'),
  devolucionFiado('DEVOLUCION_FIADO', 'Fiado corregido');

  const TipoMovimiento(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static TipoMovimiento desdeCodigo(String codigo) => values.firstWhere(
        (t) => t.codigo == codigo,
        orElse: () => TipoMovimiento.ajustePositivo,
      );
}

/// Un renglón del libro mayor del inventario.
final class MovimientoInventario extends Equatable {
  const MovimientoInventario({
    required this.id,
    required this.productoId,
    required this.tipo,
    required this.cantidad,
    this.ventaId,
    this.ordenId,
    this.reservaId,
    this.deudorId,
    this.compraId,
    this.notas,
    required this.creadoEn,
  });

  final int id;
  final int productoId;
  final TipoMovimiento tipo;

  /// Con signo: positivo entra, negativo sale.
  final double cantidad;

  final int? ventaId;
  final int? ordenId;
  final int? reservaId;
  final int? deudorId;

  /// La remisión del proveedor que trajo la mercancía.
  final int? compraId;
  final String? notas;
  final DateTime creadoEn;

  bool get entra => cantidad > 0;

  @override
  List<Object?> get props => [
        id,
        productoId,
        tipo,
        cantidad,
        ventaId,
        ordenId,
        reservaId,
        deudorId,
        compraId,
        creadoEn,
      ];
}

/// Lo que se le pide al repositorio para mover stock.
///
/// Es distinto de [MovimientoInventario] porque todavía no tiene id ni fecha:
/// los pone la base.
final class SolicitudMovimiento {
  const SolicitudMovimiento({
    required this.productoId,
    required this.cantidad,
    required this.tipo,
    this.ventaId,
    this.ordenId,
    this.reservaId,
    this.deudorId,
    this.compraId,
    this.notas,
  });

  /// Atajo para una salida: recibe la cantidad en positivo y la guarda en
  /// negativo. Evita que cada llamador tenga que acordarse del signo, que es
  /// exactamente el error que se paga caro aquí.
  factory SolicitudMovimiento.salida({
    required int productoId,
    required double cantidad,
    required TipoMovimiento tipo,
    int? ventaId,
    int? ordenId,
    int? reservaId,
    int? deudorId,
    int? compraId,
    String? notas,
  }) =>
      SolicitudMovimiento(
        productoId: productoId,
        cantidad: -cantidad.abs(),
        tipo: tipo,
        ventaId: ventaId,
        ordenId: ordenId,
        reservaId: reservaId,
        deudorId: deudorId,
        compraId: compraId,
        notas: notas,
      );

  /// Atajo para una entrada. Simétrico de [SolicitudMovimiento.salida].
  factory SolicitudMovimiento.entrada({
    required int productoId,
    required double cantidad,
    required TipoMovimiento tipo,
    int? ventaId,
    int? ordenId,
    int? reservaId,
    int? deudorId,
    int? compraId,
    String? notas,
  }) =>
      SolicitudMovimiento(
        productoId: productoId,
        cantidad: cantidad.abs(),
        tipo: tipo,
        ventaId: ventaId,
        ordenId: ordenId,
        reservaId: reservaId,
        deudorId: deudorId,
        compraId: compraId,
        notas: notas,
      );

  final int productoId;
  final double cantidad;
  final TipoMovimiento tipo;
  final int? ventaId;
  final int? ordenId;
  final int? reservaId;
  final int? deudorId;
  final int? compraId;
  final String? notas;
}
