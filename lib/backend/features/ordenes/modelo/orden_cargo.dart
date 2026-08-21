import 'package:equatable/equatable.dart';

/// Un cargo suelto de la orden: descripción y precio escritos a mano.
///
/// Es la línea libre del editor. No apunta a ningún catálogo y no mueve
/// inventario: si el repuesto estuviera dado de alta, sería un
/// [OrdenRepuesto].
class OrdenCargo extends Equatable {
  const OrdenCargo({
    required this.id,
    required this.ordenId,
    required this.descripcion,
    required this.precio,
    this.creadoEn,
  });

  final int id;
  final int ordenId;
  final String descripcion;

  /// Pesos enteros, IVA incluido (ver `iva_app.dart`).
  final int precio;

  final DateTime? creadoEn;

  @override
  List<Object?> get props => [id, ordenId, descripcion, precio];
}
