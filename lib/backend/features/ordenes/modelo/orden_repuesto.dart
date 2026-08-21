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
  /// Los dos, en pesos enteros (ver `TablaOrdenesRepuesto`).
  final int precioUnitario;
  final int costoUnitario;
  final DateTime? creadoEn;

  /// La cantidad puede ser fraccionaria (litros, metros), así que el
  /// subtotal se redondea al peso: es lo que se va a cobrar.
  int get subtotal => (cantidad * precioUnitario).round();

  @override
  List<Object?> get props =>
      [id, ordenId, productoId, productoNombre, cantidad, precioUnitario];
}