import 'package:flutter/material.dart';

import '../../../../core/formato.dart';
import '../../../share/share.dart';
import '../../productos/widgets/miniatura_linea.dart';
import '../modelo/item_carrito.dart';

/// Una línea del carrito, sobre la fila común de los tres documentos
/// ([FilaDocumento]).
///
/// No hay papelera, como en el diseño: el `–` con cantidad 1 quita la línea.
/// Por eso [ControlCantidad] va con `minimo: 0` y la cantidad 0 se traduce a
/// "quitar".
///
/// **El tope es el stock de bodega**, y es lo único que esta línea hace y las
/// otras dos no: escribir 50 unidades de algo de lo que hay 8 deja 8, sin
/// avisar con un error —el número que queda en el campo ya dice lo que pasó—.
/// Una cotización sí puede pedir lo que no hay; el mostrador no.
///
/// La cantidad va en unidades enteras: en el mostrador se venden piezas, no
/// fracciones.
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
    return FilaDocumento(
      principal: MiniaturaLinea(
        rutaImagen: item.producto.imagenUrl,
        // El carrito solo lleva productos del catálogo, así que el ícono
        // alterno solo sale cuando la foto falta.
        iconoAlterno: Icons.inventory_2_outlined,
      ),
      titulo: item.producto.nombre,
      precio: Text(
        formatearPrecio(item.precioUnitario),
        style: CampoPrecioLinea.estilo,
      ),
      acciones: [
        ControlCantidad(
          cantidad: item.cantidad.toDouble(),
          // 0 = quitar la línea: el diseño no tiene papelera.
          minimo: 0,
          maximo: item.disponible.toDouble(),
          alCambiar: (valor) =>
              valor <= 0 ? alEliminar() : alCambiarCantidad(valor.round()),
        ),
      ],
    );
  }
}
