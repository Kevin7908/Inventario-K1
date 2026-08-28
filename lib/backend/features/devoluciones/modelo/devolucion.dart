import 'package:equatable/equatable.dart';

import '../enum/enum_devoluciones.dart';

/// Una línea de la factura vista desde la devolución: cuánto se vendió,
/// cuánto ya volvió y cuánto queda por volver.
///
/// Es lo que la pantalla necesita para dejar teclear la cantidad sin poder
/// pasarse. La cuenta la hace SQL, no la vista.
final class LineaDevolvible extends Equatable {
  const LineaDevolvible({
    required this.ventaDetalleId,
    required this.productoId,
    required this.descripcion,
    required this.cantidadVendida,
    required this.cantidadDevuelta,
    required this.precioUnitario,
  });

  final int ventaDetalleId;

  /// `null` en las líneas de servicio: un servicio prestado no se devuelve a
  /// la estantería, y por eso tampoco mueve inventario.
  final int? productoId;

  /// El nombre congelado en la factura, no el del catálogo de hoy.
  final String descripcion;

  final double cantidadVendida;
  final double cantidadDevuelta;

  /// En pesos enteros, como se cobró.
  final int precioUnitario;

  /// Lo que todavía se puede traer de vuelta.
  double get disponible => cantidadVendida - cantidadDevuelta;

  bool get esProducto => productoId != null;

  @override
  List<Object?> get props => [
        ventaDetalleId,
        productoId,
        descripcion,
        cantidadVendida,
        cantidadDevuelta,
        precioUnitario,
      ];
}

/// Un renglón ya guardado de una devolución.
final class DevolucionLinea extends Equatable {
  const DevolucionLinea({
    required this.id,
    required this.ventaDetalleId,
    this.productoId,
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
  });

  final int id;
  final int ventaDetalleId;
  final int? productoId;

  /// Del `JOIN` con `venta_detalles`: el snapshot vive allá, aquí no se copia.
  final String descripcion;

  final double cantidad;
  final int precioUnitario;

  /// Lo que se le regresó al cliente por esta línea, en pesos enteros.
  int get subtotal => (cantidad * precioUnitario).round();

  @override
  List<Object?> get props =>
      [id, ventaDetalleId, productoId, descripcion, cantidad, precioUnitario];
}

/// El documento: lo que volvió de una venta, cuándo y por qué.
final class Devolucion extends Equatable {
  const Devolucion({
    required this.id,
    required this.numero,
    required this.ventaId,
    required this.numeroFactura,
    required this.motivo,
    required this.total,
    this.notas,
    required this.usuarioId,
    this.recibidoPor = '',
    required this.creadoEn,
    this.lineas = const [],
  });

  final int id;
  final String numero;
  final int ventaId;

  /// Del `JOIN` con `ventas`. La factura contra la que se devolvió.
  final String numeroFactura;

  final MotivoDevolucion motivo;

  /// En pesos enteros.
  final int total;

  final String? notas;
  final int usuarioId;

  /// Quién la recibió, del `JOIN` con `usuarios` y `personas`. Cadena vacía
  /// solo si la consulta no lo pidió: `usuario_id` es `NOT NULL`.
  final String recibidoPor;

  final DateTime creadoEn;
  final List<DevolucionLinea> lineas;

  @override
  List<Object?> get props => [
        id,
        numero,
        ventaId,
        numeroFactura,
        motivo,
        total,
        notas,
        usuarioId,
        recibidoPor,
        creadoEn,
        lineas,
      ];
}

/// Lo que se le pide al repositorio para devolver una línea.
///
/// No lleva el precio: lo pone el repositorio leyéndolo de `venta_detalles`.
/// Si viniera de la vista, un total mal calculado arriba se guardaría como si
/// fuera el precio al que se vendió.
final class LineaADevolver {
  const LineaADevolver({required this.ventaDetalleId, required this.cantidad});

  final int ventaDetalleId;
  final double cantidad;
}
