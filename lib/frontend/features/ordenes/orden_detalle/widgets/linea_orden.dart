import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/formato.dart';
import '../../../../features/productos/vista/producto_vista.dart'
    show MiniaturaProducto;
import '../../../../share2/share2.dart';
import '../modelo/linea_orden_editor.dart';

/// Una línea de la orden, con la fila del carrito del diseño: miniatura de 48,
/// nombre, precio en verde y el control de la derecha.
///
/// ## Qué cambia según el tipo, y por qué
///
/// - **Repuesto**: lleva `– n +`, como en cotizaciones. El `–` con cantidad 1
///   quita la línea, así que no hace falta papelera.
/// - **Servicio** y **cargo**: no tienen cantidad —`ordenes_tareas` y
///   `ordenes_cargos` ni siquiera tienen la columna—, así que llevan papelera.
///   Fingir un `– 1 +` que no se puede subir sería mentir sobre el modelo.
///
/// El servicio muestra además **quién lo hace** y una casilla para marcarlo
/// hecho: es el estado de completado de la tarea, que es lo que diferencia una
/// orden de una cotización.
class LineaOrden extends StatefulWidget {
  const LineaOrden({
    super.key,
    required this.linea,
    required this.editable,
    required this.alCambiarCantidad,
    required this.alCambiarPrecio,
    required this.alEliminar,
    required this.alMarcarCompletada,
    this.imagen,
  });

  final LineaOrdenEditor linea;

  /// En `false` la fila se ve pero no se toca: la orden está entregada o
  /// anulada.
  final bool editable;

  final ValueChanged<double> alCambiarCantidad;
  final ValueChanged<int> alCambiarPrecio;
  final VoidCallback alEliminar;
  final ValueChanged<bool> alMarcarCompletada;

  /// Ruta de la foto del producto. `null` en servicios y cargos, que muestran
  /// el ícono de su tipo.
  final String? imagen;

  static IconData iconoDe(TipoLineaOrden tipo) => switch (tipo) {
        TipoLineaOrden.repuesto => Icons.inventory_2_outlined,
        TipoLineaOrden.servicio => Icons.build_outlined,
        TipoLineaOrden.cargo => Icons.edit_outlined,
      };

  @override
  State<LineaOrden> createState() => _LineaOrdenState();
}

class _LineaOrdenState extends State<LineaOrden> {
  late final TextEditingController _precio = TextEditingController(
    text: widget.linea.precioUnitario == 0 ? '' : '${widget.linea.precioUnitario}',
  );
  final _focoPrecio = FocusNode();

  @override
  void dispose() {
    _precio.dispose();
    _focoPrecio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linea = widget.linea;

    // El precio del repuesto lo pone el catálogo, igual que en cotizaciones:
    // una orden que se despega de la lista de precios deja de poder compararse
    // con el inventario. El de la mano de obra y el del cargo se teclean.
    final precioEditable =
        widget.editable && linea.tipo != TipoLineaOrden.repuesto;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ColoresApp.borderFila)),
      ),
      child: Row(
        children: [
          _Miniatura(tipo: linea.tipo, imagen: widget.imagen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  linea.descripcion,
                  style: TipografiaApp.cuerpoMedium.copyWith(
                    fontSize: 13,
                    decoration:
                        linea.completado ? TextDecoration.lineThrough : null,
                    color: linea.completado ? ColoresApp.textMuted : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (linea.tecnicoNombre != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    linea.tecnicoNombre!,
                    style: TipografiaApp.caption.copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                _precioWidget(editable: precioEditable),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ..._controles(linea),
        ],
      ),
    );
  }

  List<Widget> _controles(LineaOrdenEditor linea) {
    if (linea.tipo.tieneCantidad) {
      return [
        ControlCantidad(
          cantidad: linea.cantidad,
          // 0 = quitar la línea: el diseño no tiene papelera.
          minimo: 0,
          alCambiar: widget.editable
              ? (valor) => valor <= 0
                  ? widget.alEliminar()
                  : widget.alCambiarCantidad(valor)
              : null,
        ),
      ];
    }

    return [
      // Solo los servicios se marcan hechos: un cargo no se "completa".
      if (linea.tipo == TipoLineaOrden.servicio)
        BotonIcono(
          icono: linea.completado
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          tooltip: linea.completado
              ? 'Marcar la tarea como pendiente'
              : 'Marcar la tarea como hecha',
          color: linea.completado
              ? ColoresApp.statusSuccess
              : ColoresApp.textMuted,
          alPresionar: widget.editable
              ? () => widget.alMarcarCompletada(!linea.completado)
              : null,
        ),
      BotonIcono(
        icono: Icons.delete_outline_rounded,
        tooltip: 'Quitar de la orden',
        color: ColoresApp.statusDanger,
        alPresionar: widget.editable ? widget.alEliminar : null,
      ),
    ];
  }

  Widget _precioWidget({required bool editable}) {
    final estilo = TipografiaApp.cuerpoMedium.copyWith(
      fontSize: 13,
      color: ColoresApp.castletonGreen,
    );

    if (!editable) {
      return Text(formatearPrecio(widget.linea.precioUnitario), style: estilo);
    }

    return SizedBox(
      height: 22,
      child: TextField(
        controller: _precio,
        focusNode: _focoPrecio,
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

/// Cuadro de 48 del diseño: la foto del repuesto, o el ícono del tipo cuando
/// no hay ninguna que mostrar.
class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.tipo, required this.imagen});

  final TipoLineaOrden tipo;
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
        LineaOrden.iconoDe(tipo),
        size: 18,
        color: ColoresApp.textDisabled,
      ),
    );
  }
}
