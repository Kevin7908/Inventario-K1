import 'package:equatable/equatable.dart';

class OrdenRepuesto extends Equatable {
  const OrdenRepuesto({
    required this.id,
    required this.ordenId,
    required this.productoId,
    required this.productoNombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.costoUnitario,
    this.creadoEn,
  });

  final int id;
  final int ordenId;
  final int productoId;
  final String productoNombre;
  final double cantidad;
  final double precioUnitario;
  final double costoUnitario;
  final DateTime? creadoEn;

  double get subtotal => cantidad * precioUnitario;

  @override
  List<Object?> get props =>
      [id, ordenId, productoId, productoNombre, cantidad, precioUnitario];
}