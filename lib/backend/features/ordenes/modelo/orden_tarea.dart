import 'package:equatable/equatable.dart';

class OrdenTarea extends Equatable {

  final int id;
  final int ordenId;
  final int servicioId;
  final int tecnicoId;
  final String servicioNombre;
  final String tecnicoNombre;
  /// En pesos enteros (ver `TablaOrdenesTarea`).
  final int precioPactado;
  final String? notas;
  final bool completado;
  final DateTime? creadoEn;

  const OrdenTarea({
    required this.id,
    required this.ordenId,
    required this.servicioId,
    required this.tecnicoId,
    required this.servicioNombre,
    required this.tecnicoNombre,
    required this.precioPactado,
    this.notas,
    required this.completado,
    this.creadoEn,
  });

  @override
  List<Object?> get props =>
      [id, ordenId, servicioId, tecnicoId, servicioNombre, tecnicoNombre, precioPactado, notas, completado];
}