import 'package:flutter/material.dart';

import '../../../../core/formato.dart';
import '../../../share2/share2.dart';
import '../../productos/vista/producto_vista.dart' show MiniaturaProducto;
import '../modelo/item_carrito.dart';

/// Una línea del carrito, con la fila del diseño: miniatura de 48, nombre,
/// precio en verde y el `– n +` a la derecha.
///
/// No hay papelera, como en el diseño: el `–` con cantidad 1 quita la línea.
/// Por eso [ControlCantidad] va con `minimo: 0` y la cantidad 0 se traduce a
/// "quitar".
///
/// El tope es el stock de bodega: escribir 50 unidades de algo de lo que hay 8
/// deja 8, sin avisar con un error — el número que queda en el campo ya dice
/// lo que pasó.
class LineaCarrito extends StatelessWidget {
  const LineaCarrito({
    super.key,
    required this.item,
    required this.alCambiarCantidad,
    required this.alEliminar,
  });

  final ItemCarrito item;
  final ValueChanged<int> alCambiarCantidad;
  final VoidCallback alEliminar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ColoresApp.borderFila)),
      ),
      child: Row(
        children: [
          MiniaturaProducto(
            rutaImagen: item.producto.imagenUrl,
            lado: 48,
            radio: 11,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.producto.nombre,
                  style: TipografiaApp.cuerpoMedium.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  formatearPrecio(item.precioUnitario),
                  style: TipografiaApp.cuerpoMedium.copyWith(
                    fontSize: 13,
                    color: ColoresApp.castletonGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ControlCantidad(
            cantidad: item.cantidad.toDouble(),
            // 0 = quitar la línea: el diseño no tiene papelera.
            minimo: 0,
            maximo: item.disponible.toDouble(),
            alCambiar: (valor) => valor <= 0
                ? alEliminar()
                : alCambiarCantidad(valor.round()),
          ),
        ],
      ),
    );
  }
}
