import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../backend/features/cotizaciones/enum/enum_cotizacion.dart';
import '../../../../../core/formato.dart';
import '../../../../features/productos/vista/producto_vista.dart'
    show MiniaturaProducto;
import '../../../../share2/share2.dart';
import '../modelo/item_cotizacion_editor.dart';

/// Una línea de la cotización, con la fila del carrito del diseño: miniatura
/// de 48, nombre, precio en verde y el `– n +` a la derecha.
///
/// No hay papelera, como en el diseño: el `–` con cantidad 1 quita la línea.
/// Por eso [ControlCantidad] va con `minimo: 0` y la cantidad 0 se traduce a
/// "quitar".
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

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ColoresApp.borderFila)),
      ),
      child: Row(
        children: [
          _Miniatura(tipo: item.tipo, imagen: widget.imagen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.descripcion,
                  style: TipografiaApp.cuerpoMedium.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                _precioWidget(),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ControlCantidad(
            cantidad: item.cantidad,
            // 0 = quitar la línea: el diseño no tiene papelera.
            minimo: 0,
            alCambiar: (valor) => valor <= 0
                ? widget.alEliminar()
                : widget.alCambiarCantidad(valor),
          ),
        ],
      ),
    );
  }

  Widget _precioWidget() {
    final estilo = TipografiaApp.cuerpoMedium.copyWith(
      fontSize: 13,
      color: ColoresApp.castletonGreen,
    );

    if (!widget.item.tipo.precioManual) {
      return Text(formatearPrecio(widget.item.precioUnitario), style: estilo);
    }

    return SizedBox(
      height: 22,
      child: TextField(
        controller: _precio,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: estilo,
        onChanged: (texto) => widget.alCambiarPrecio(int.tryParse(texto) ?? 0),
        decoration: InputDecoration(
          isDense: true,
          prefixText: r'$',
          prefixStyle: estilo,
          hintText: 'Precio',
          hintStyle: TipografiaApp.deshabilitado(estilo),
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

/// Cuadro de 48 del diseño: la foto del producto, o el ícono del tipo cuando
/// no hay ninguna que mostrar.
class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.tipo, required this.imagen});

  final TipoItemCotizacion tipo;
  final String? imagen;

  @override
  Widget build(BuildContext context) {
    final ruta = imagen;
    if (ruta != null && ruta.isNotEmpty) {
      return MiniaturaProducto(rutaImagen: ruta, lado: 48, radio: 11);
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: ColoresApp.bgInput,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        LineaCotizacion.iconoDe(tipo),
        size: 18,
        color: ColoresApp.textDisabled,
      ),
    );
  }
}
