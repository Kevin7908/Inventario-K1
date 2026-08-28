import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Una línea de un documento que se está armando: carrito, cotización u orden.
///
/// Es solo el reparto de la fila del diseño —cuadro de 48, texto que se
/// estira, controles a la derecha— y la separación entre filas. **No decide
/// nada**: quién va en el cuadro, si el precio se teclea o se muestra, y qué
/// controles lleva, lo resuelve el módulo y llega ya construido.
///
/// Esa es la razón de que reciba `Widget` y no banderas. Los tres documentos
/// difieren justo en esas tres celdas —el POS no edita precios, la orden marca
/// tareas hechas—, y una bandera por diferencia habría convertido esto en el
/// widget con quince parámetros que nadie se atreve a tocar.
///
/// Parámetros:
/// - [principal]: el cuadro de 48 de la izquierda (una miniatura, un ícono).
/// - [titulo]: la descripción de la línea. Se recorta con puntos suspensivos.
/// - [precio]: la celda de importe, bajo el título. Texto o campo tecleable.
/// - [subtitulo]: línea tenue entre el título y el precio (quién hace la
///   tarea, por ejemplo). Opcional.
/// - [tachado]: cruza el título y lo apaga. Para lo que ya se hizo.
/// - [acciones]: lo de la derecha —un control de cantidad, botones—, en el
///   orden en que se pintan.
///
/// Ejemplo:
/// ```dart
/// FilaDocumento(
///   principal: MiniaturaLinea(rutaImagen: item.imagen, iconoAlterno: icono),
///   titulo: item.descripcion,
///   precio: Text(formatearPrecio(item.precioUnitario)),
///   acciones: [ControlCantidad(cantidad: item.cantidad, alCambiar: cambiar)],
/// )
/// ```
class FilaDocumento extends StatelessWidget {
  const FilaDocumento({
    super.key,
    required this.principal,
    required this.titulo,
    required this.precio,
    this.subtitulo,
    this.tachado = false,
    this.acciones = const [],
  });

  final Widget principal;
  final String titulo;
  final Widget precio;
  final String? subtitulo;
  final bool tachado;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    final subtitulo = this.subtitulo;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ColoresApp.borderFila)),
      ),
      child: Row(
        children: [
          principal,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  style: TipografiaApp.cuerpoMedium.copyWith(
                    fontSize: 13,
                    decoration: tachado ? TextDecoration.lineThrough : null,
                    color: tachado ? ColoresApp.textMuted : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitulo != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitulo,
                    style: TipografiaApp.caption.copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                precio,
              ],
            ),
          ),
          const SizedBox(width: 12),
          ...acciones,
        ],
      ),
    );
  }
}
