import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';
import 'columna_tabla.dart';
import 'fila_tabla.dart';

/// Tabla configurable con columnas dinámicas.
///
/// Recibe una lista de [ColumnaTabla] que define el encabezado, ancho y
/// contenido de cada columna, y pinta una fila por cada ítem de [items].
///
/// Parámetros:
/// - [columnas]: definición de las columnas de la tabla.
/// - [items]: datos a mostrar, uno por fila.
/// - [alPresionarFila]: callback opcional al tocar una fila. Recibe el ítem tocado.
/// - [itemSeleccionado]: ítem que se resalta como seleccionado, si aplica.
///
/// Ejemplo:
/// ```dart
/// TablaGenerica<UnidadMedida>(
///   items: unidades,
///   columnas: [
///     ColumnaTabla(
///       titulo: 'Unidad',
///       flex: 2,
///       constructor: (u) => Text(u.nombre, style: TipografiaApp.cuerpoMedium),
///     ),
///     ColumnaTabla(
///       titulo: 'Abreviatura',
///       constructor: (u) => Text(u.abreviatura),
///     ),
///     ColumnaTabla(
///       titulo: 'Uso típico',
///       flex: 3,
///       constructor: (u) => Text(u.descripcion ?? '—'),
///     ),
///   ],
/// )
/// ```
class TablaGenerica<T> extends StatelessWidget {
  const TablaGenerica({
    super.key,
    required this.columnas,
    required this.items,
    this.alPresionarFila,
    this.itemSeleccionado,
  });

  final List<ColumnaTabla<T>> columnas;
  final List<T> items;
  final ValueChanged<T>? alPresionarFila;
  final T? itemSeleccionado;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Encabezado<T>(columnas: columnas),
          Divider(color: ColoresApp.border, height: 1, thickness: 1),
          for (var i = 0; i < items.length; i++) ...[
            FilaTabla<T>(
              item: items[i],
              columnas: columnas,
              seleccionada: items[i] == itemSeleccionado,
              alPresionar: alPresionarFila == null
                  ? null
                  : () => alPresionarFila!(items[i]),
            ),
            if (i < items.length - 1)
              Divider(color: ColoresApp.border, height: 1, thickness: 1),
          ],
        ],
      ),
    );
  }
}

class _Encabezado<T> extends StatelessWidget {
  const _Encabezado({required this.columnas});

  final List<ColumnaTabla<T>> columnas;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          for (final columna in columnas) _celda(columna),
        ],
      ),
    );
  }

  Widget _celda(ColumnaTabla<T> columna) {
    final contenido = Align(
      alignment: columna.alineacion,
      child: Text(
        columna.titulo.toUpperCase(),
        style: TipografiaApp.overline,
      ),
    );

    if (columna.ancho != null) {
      return SizedBox(width: columna.ancho, child: contenido);
    }
    return Expanded(flex: columna.flex, child: contenido);
  }
}
