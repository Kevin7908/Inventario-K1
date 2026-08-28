import 'package:flutter/material.dart';

import '../../../../../core/formato.dart';
import '../../../../features/productos/widgets/miniatura_linea.dart';
import '../../../../share/share.dart';
import '../modelo/linea_orden_editor.dart';

/// Una línea de la orden, sobre la fila común de los tres documentos
/// ([FilaDocumento]).
///
/// ## Qué cambia según el tipo, y por qué
///
/// - **Repuesto**: lleva `– n +`, como en cotizaciones. El `–` con cantidad 1
///   quita la línea, así que no hace falta papelera. **Tope el stock**: desde
///   que anotar un repuesto lo descuenta del inventario, pedir más de lo que
///   hay lo rechaza el repositorio; recortar aquí evita el viaje.
/// - **Servicio** y **cargo**: no tienen cantidad —`ordenes_tareas` y
///   `ordenes_cargos` ni siquiera tienen la columna—, así que llevan papelera.
///   Fingir un `– 1 +` que no se puede subir sería mentir sobre el modelo.
///
/// El servicio muestra además **quién lo hace** y una casilla para marcarlo
/// hecho: es el estado de completado de la tarea, que es lo que diferencia una
/// orden de una cotización.
///
/// Las cantidades van en unidades enteras, como en el resto de la app.
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
    this.disponible,
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

  /// Cuántas unidades más admite la línea: lo que queda en bodega **más** lo
  /// que esta línea ya tiene anotado, porque eso último ya salió del estante.
  /// `null` cuando no se sabe, y entonces el control no acota.
  final double? disponible;

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

    return FilaDocumento(
      principal: MiniaturaLinea(
        rutaImagen: widget.imagen,
        iconoAlterno: LineaOrden.iconoDe(linea.tipo),
      ),
      titulo: linea.descripcion,
      subtitulo: linea.tecnicoNombre,
      tachado: linea.completado,
      precio: precioEditable
          ? CampoPrecioLinea(
              controlador: _precio,
              foco: _focoPrecio,
              alCambiar: widget.alCambiarPrecio,
            )
          : Text(
              formatearPrecio(linea.precioUnitario),
              style: CampoPrecioLinea.estilo,
            ),
      acciones: _acciones(linea),
    );
  }

  List<Widget> _acciones(LineaOrdenEditor linea) {
    if (linea.tipo.tieneCantidad) {
      return [
        ControlCantidad(
          cantidad: linea.cantidad,
          // 0 = quitar la línea: el diseño no tiene papelera.
          minimo: 0,
          maximo: widget.disponible,
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
}
