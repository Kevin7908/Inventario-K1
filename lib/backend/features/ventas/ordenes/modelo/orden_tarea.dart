import 'package:equatable/equatable.dart';

class OrdenTarea extends Equatable {
  
  final int id;
  final int ordenId;
  final String servicioNombre;
  final String tecnicoNombre;
  final double precioPactado;
  final String? notas;
  final bool completado;
  final DateTime? creadoEn;       

  const OrdenTarea({
    required this.id,
    required this.ordenId,
    required this.servicioNombre,
    required this.tecnicoNombre,
    required this.precioPactado,
    this.notas,
    required this.completado,
    this.creadoEn,
  });

  @override
  List<Object?> get props =>
      [id, ordenId, servicioNombre, tecnicoNombre, precioPactado, notas, completado];
}