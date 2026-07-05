import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import 'columna_tabla.dart';

/// Fila individual de [TablaGenerica], con estilos de hover y selección.
///
/// Parámetros:
/// - [item]: dato de la fila.
/// - [columnas]: columnas que definen qué y cómo se pinta cada celda.
/// - [alPresionar]: callback opcional al tocar la fila.
/// - [seleccionada]: resalta la fila con un fondo distinto cuando es `true`.
///
/// Ejemplo:
/// ```dart
/// FilaTabla<UnidadMedida>(
///   item: unidad,
///   columnas: columnas,
///   alPresionar: () => controlador.seleccionar(unidad),
/// )
/// ```
class FilaTabla<T> extends StatefulWidget {
  const FilaTabla({
    super.key,
    required this.item,
    required this.columnas,
    this.alPresionar,
    this.seleccionada = false,
  });

  final T item;
  final List<ColumnaTabla<T>> columnas;
  final VoidCallback? alPresionar;
  final bool seleccionada;

  @override
  State<FilaTabla<T>> createState() => _FilaTablaState<T>();
}

class _FilaTablaState<T> extends State<FilaTabla<T>> {
  bool _conHover = false;

  @override
  Widget build(BuildContext context) {
    final Color fondo = widget.seleccionada
        ? ColoresApp.statusSuccessBg
        : _conHover
            ? ColoresApp.bgCardHover
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _conHover = true),
      onExit: (_) => setState(() => _conHover = false),
      child: InkWell(
        onTap: widget.alPresionar,
        child: Container(
          color: fondo,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              for (final columna in widget.columnas) _celda(columna),
            ],
          ),
        ),
      ),
    );
  }

  Widget _celda(ColumnaTabla<T> columna) {
    final contenido = Align(
      alignment: columna.alineacion,
      child: columna.constructor(widget.item),
    );

    if (columna.ancho != null) {
      return SizedBox(width: columna.ancho, child: contenido);
    }
    return Expanded(flex: columna.flex, child: contenido);
  }
}
