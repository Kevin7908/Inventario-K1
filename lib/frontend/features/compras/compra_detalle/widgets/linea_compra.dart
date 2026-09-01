import 'package:flutter/material.dart';

import '../../../../../core/formato.dart';
import '../../../../share/share.dart';
import '../../../productos/widgets/miniatura_linea.dart';

/// Una línea de la remisión: producto, cuánto llegó y a cuánto salió cada
/// unidad.
///
/// Es la hermana de `LineaOrden` con el signo cambiado: allí se teclea el
/// precio de venta y aquí el **costo**, que es el dato que el módulo existe
/// para guardar. El `–` con cantidad 1 quita la línea, así que no hace falta
/// papelera.
///
/// Parámetros:
/// - [descripcion] y [sku]: del producto elegido.
/// - [imagen]: ruta de su foto, si tiene.
/// - [cantidad] y [costoUnitario]: lo que lleva la línea ahora mismo.
/// - [alCambiarCantidad], [alCambiarCosto], [alEliminar]: avisan hacia arriba;
///   la línea no guarda nada por su cuenta más allá del texto en edición.
///
/// Ejemplo:
/// ```dart
/// LineaCompra(
///   descripcion: producto.nombre,
///   sku: producto.sku,
///   cantidad: 12,
///   costoUnitario: 6500,
///   alCambiarCantidad: (v) => _cambiarCantidad(i, v),
///   alCambiarCosto: (v) => _cambiarCosto(i, v),
///   alEliminar: () => _quitar(i),
/// )
/// ```
class LineaCompra extends StatefulWidget {
  const LineaCompra({
    super.key,
    required this.descripcion,
    required this.sku,
    required this.cantidad,
    required this.costoUnitario,
    required this.alCambiarCantidad,
    required this.alCambiarCosto,
    required this.alEliminar,
    this.imagen,
    this.editable = true,
  });

  final String descripcion;
  final String? sku;
  final String? imagen;
  final double cantidad;
  final int costoUnitario;

  final ValueChanged<double> alCambiarCantidad;
  final ValueChanged<int> alCambiarCosto;
  final VoidCallback alEliminar;

  /// En `false` la fila se ve pero no se toca: la remisión está anulada.
  final bool editable;

  @override
  State<LineaCompra> createState() => _LineaCompraState();
}

class _LineaCompraState extends State<LineaCompra> {
  late final TextEditingController _costo = TextEditingController(
    text: widget.costoUnitario == 0 ? '' : '${widget.costoUnitario}',
  );
  final _focoCosto = FocusNode();

  @override
  void dispose() {
    _costo.dispose();
    _focoCosto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FilaDocumento(
      principal: MiniaturaLinea(
        rutaImagen: widget.imagen,
        iconoAlterno: Icons.inventory_2_outlined,
      ),
      titulo: widget.descripcion,
      // El subtítulo lleva el SKU y lo que suma la línea: al teclear costos
      // uno por uno, ver el parcial evita tener que sumar de cabeza.
      subtitulo: '${widget.sku ?? ''} · '
          '${formatearPrecio((widget.cantidad * widget.costoUnitario).round())}',
      precio: widget.editable
          ? CampoPrecioLinea(
              controlador: _costo,
              foco: _focoCosto,
              alCambiar: widget.alCambiarCosto,
            )
          : Text(
              formatearPrecio(widget.costoUnitario),
              style: CampoPrecioLinea.estilo,
            ),
      acciones: [
        ControlCantidad(
          cantidad: widget.cantidad,
          // 0 = quitar la línea: el diseño no tiene papelera. Con decimales
          // porque hay mercancía que llega por litro y por metro.
          minimo: 0,
          permitirDecimales: true,
          alCambiar: widget.editable
              ? (valor) => valor <= 0
                  ? widget.alEliminar()
                  : widget.alCambiarCantidad(valor)
              : null,
        ),
      ],
    );
  }
}
