import 'package:equatable/equatable.dart';
import '../enum/enum_cotizacion.dart';

class CotizacionItem extends Equatable {
  final int id;
  final int cotizacionId;
  final TipoItemCotizacion tipoItem;
  final int? referenciaId;
  final String descripcion;
  final double cantidad;
  final int precioUnitario;
  final int subtotal;

  const CotizacionItem({
    required this.id,
    required this.cotizacionId,
    required this.tipoItem,
    this.referenciaId,
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  @override
  List<Object?> get props => [
        id,
        cotizacionId,
        tipoItem,
        referenciaId,
        descripcion,
        cantidad,
        precioUnitario,
        subtotal,
      ];
}
