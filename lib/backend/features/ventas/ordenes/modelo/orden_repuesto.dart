import 'package:equatable/equatable.dart';

class OrdenRepuesto extends Equatable {
  const OrdenRepuesto({
    required this.id,
    required this.ordenId,
    required this.productoNombre,
    required this.cantidad,
    required this.precioUnitario,
    this.creadoEn,
  });

  final int id;
  final int ordenId;
  final String productoNombre;
  final double cantidad;
  final double precioUnitario;
  final DateTime? creadoEn;      

  double get subtotal => cantidad * precioUnitario;

  @override
  List<Object?> get props =>
      [id, ordenId, productoNombre, cantidad, precioUnitario];
}