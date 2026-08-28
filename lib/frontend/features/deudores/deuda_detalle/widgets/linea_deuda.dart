import 'package:flutter/material.dart';

import '../../../../../backend/features/deudores/modelo/deudor_item.dart';
import '../../../../../core/formato.dart';
import '../../../../features/productos/widgets/miniatura_linea.dart';
import '../../../../share2/share2.dart';

/// Una línea de lo fiado, sobre la fila común de los documentos
/// ([FilaDocumento]).
///
/// Es la misma que la de una reserva —el precio lo pone el catálogo y el `–`
/// con cantidad 1 quita la línea— con una diferencia que conviene tener
/// presente: **quitarla no es una devolución del cliente**. Lo fiado salió del
/// taller montado en una moto; borrar la línea significa que nunca debió
/// anotarse, y por eso el repuesto vuelve al estante.
///
/// El tope es el stock: fiar descuenta en el acto y el repositorio rechaza
/// pedir más de lo que hay.
class LineaDeuda extends StatelessWidget {
  const LineaDeuda({
    super.key,
    required this.linea,
    required this.editable,
    required this.alCambiarCantidad,
    required this.alEliminar,
    this.disponible,
  });

  final DeudorItem linea;

  /// En `false` la fila se ve pero no se toca: la deuda está pagada o dada por
  /// perdida.
  final bool editable;

  final ValueChanged<double> alCambiarCantidad;
  final VoidCallback alEliminar;

  /// Cuántas unidades admite como máximo: lo que queda en bodega **más** lo
  /// que esta línea ya se llevó, porque eso salió del estante al fiarlo.
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
