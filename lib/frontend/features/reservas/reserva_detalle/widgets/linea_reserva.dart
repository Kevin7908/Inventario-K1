import 'package:flutter/material.dart';

import '../../../../../backend/features/reservas/modelo/reserva_item.dart';
import '../../../../../core/formato.dart';
import '../../../../features/productos/widgets/miniatura_linea.dart';
import '../../../../share2/share2.dart';

/// Una línea de la reserva, sobre la fila común de los documentos
/// ([FilaDocumento]).
///
/// Es la más simple de las cuatro: una reserva solo aparta productos del
/// catálogo, así que no hay tipos ni precio tecleable —el precio lo pone el
/// catálogo, como en cotizaciones y órdenes—.
///
/// El `–` con cantidad 1 quita la línea, así que no hace falta papelera. El
/// tope es el stock: apartar descuenta en el acto, y el repositorio rechaza
/// pedir más de lo que hay.
class LineaReserva extends StatelessWidget {
  const LineaReserva({
    super.key,
    required this.linea,
    required this.editable,
    required this.alCambiarCantidad,
    required this.alEliminar,
    this.disponible,
  });

  final ReservaItem linea;

  /// En `false` la fila se ve pero no se toca: la reserva está completada o
  /// cancelada.
  final bool editable;

  final ValueChanged<double> alCambiarCantidad;
  final VoidCallback alEliminar;

  /// Cuántas unidades admite como máximo: lo que queda en bodega **más** lo
  /// que esta línea ya apartó, porque eso salió del estante al reservarlo.
  /// `null` cuando no se sabe, y entonces el control no acota.
  final double? disponible;

  @override
  Widget build(BuildContext context) {
    return FilaDocumento(
      principal: MiniaturaLinea(
        rutaImagen: linea.imagenUrl,
        iconoAlterno: Icons.inventory_2_outlined,
      ),
      titulo: linea.nombreProducto,
      subtitulo: linea.sku,
      precio: Text(
        formatearPrecio(linea.precioUnitario),
        style: CampoPrecioLinea.estilo,
      ),
      acciones: [
        ControlCantidad(
          cantidad: linea.cantidad,
          // 0 = quitar la línea: el diseño no tiene papelera.
          minimo: 0,
          maximo: disponible,
          alCambiar: editable
              ? (valor) => valor <= 0 ? alEliminar() : alCambiarCantidad(valor)
              : null,
        ),
      ],
    );
  }
}
