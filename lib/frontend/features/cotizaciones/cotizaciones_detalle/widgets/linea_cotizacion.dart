import 'package:flutter/material.dart';

import '../../../../../backend/features/cotizaciones/enum/enum_cotizacion.dart';
import '../../../../../core/formato.dart';
import '../../../../features/productos/widgets/miniatura_linea.dart';
import '../../../../share/share.dart';
import '../modelo/item_cotizacion_editor.dart';

/// Una línea de la cotización, sobre la fila común de los tres documentos
/// ([FilaDocumento]).
///
/// No hay papelera, como en el diseño: el `–` con cantidad 1 quita la línea.
/// Por eso [ControlCantidad] va con `minimo: 0` y la cantidad 0 se traduce a
/// "quitar".
///
/// **No hay tope de stock**, a diferencia del carrito: se cotiza lo que el
/// cliente pide, esté o no en bodega. Cuando la cotización se convierte en
/// reserva es cuando el stock manda.
///
/// El precio solo se puede escribir cuando el tipo lo permite
/// ([TipoItemCotizacion.precioManual]); el de un producto lo pone el catálogo.
/// Cuando se puede, el campo ocupa el sitio exacto del texto verde, para que
/// la fila mida lo mismo en los tres tipos.
class LineaCotizacion extends StatefulWidget {
  const LineaCotizacion({
    super.key,
    required this.item,
    required this.alCambiarCantidad,
    required this.alCambiarPrecio,
    required this.alEliminar,
    this.imagen,
  });

  final ItemCotizacionEditor item;
  final ValueChanged<double> alCambiarCantidad;
  final ValueChanged<int> alCambiarPrecio;
  final VoidCallback alEliminar;

  /// Ruta de la foto del producto. `null` en servicios y líneas libres, que
  /// muestran el ícono de su tipo.
  final String? imagen;

  static IconData iconoDe(TipoItemCotizacion tipo) => switch (tipo) {
        TipoItemCotizacion.producto => Icons.inventory_2_outlined,
        TipoItemCotizacion.servicio => Icons.build_outlined,
        TipoItemCotizacion.libre => Icons.edit_outlined,
      };

  @override
  State<LineaCotizacion> createState() => _LineaCotizacionState();
}

class _LineaCotizacionState extends State<LineaCotizacion> {
  late final TextEditingController _precio = TextEditingController(
    text: widget.item.precioUnitario == 0 ? '' : '${widget.item.precioUnitario}',
  );

  @override
  void dispose() {
    _precio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return FilaDocumento(
      principal: MiniaturaLinea(
        rutaImagen: widget.imagen,
        iconoAlterno: LineaCotizacion.iconoDe(item.tipo),
      ),
      titulo: item.descripcion,
      precio: item.tipo.precioManual
          ? CampoPrecioLinea(
              controlador: _precio,
              alCambiar: widget.alCambiarPrecio,
            )
          : Text(
              formatearPrecio(item.precioUnitario),
              style: CampoPrecioLinea.estilo,
            ),
      acciones: [
        ControlCantidad(
          cantidad: item.cantidad,
          // 0 = quitar la línea: el diseño no tiene papelera.
          minimo: 0,
          alCambiar: (valor) =>
              valor <= 0 ? widget.alEliminar() : widget.alCambiarCantidad(valor),
        ),
      ],
    );
  }
}
