import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';
import 'columna_tabla.dart';
import 'fila_tabla.dart';

/// Tabla configurable con columnas dinámicas y **encabezado fijo**.
///
/// Recibe una lista de [ColumnaTabla] que define el encabezado, ancho y
/// contenido de cada columna, y pinta una fila por cada ítem de [items].
///
/// El encabezado queda anclado arriba y solo scrollean las filas, de modo que
/// los títulos de columna siguen visibles al recorrer listas largas. Por eso
/// la tabla **ocupa todo el alto disponible** y necesita un padre que le dé
/// una altura acotada (`Expanded`, `SizedBox`, `Flexible`…). Envolverla en un
/// `SingleChildScrollView` anularía el encabezado fijo.
///
/// Parámetros:
/// - [columnas]: definición de las columnas de la tabla.
/// - [items]: datos a mostrar, uno por fila.
/// - [alPresionarFila]: callback opcional al tocar una fila. Recibe el ítem tocado.
/// - [itemSeleccionado]: ítem que se resalta como seleccionado, si aplica.
/// - [mensajeVacio]: texto centrado que se muestra cuando [items] está vacío.
///
/// Ejemplo:
/// ```dart
/// Expanded(
///   child: TablaGenerica<UnidadMedida>(
///     items: unidades,
///     mensajeVacio: 'No hay unidades registradas',
///     columnas: [
///       ColumnaTabla(
///         titulo: 'Unidad',
///         flex: 2,
///         constructor: (u) => Text(u.nombre, style: TipografiaApp.cuerpoMedium),
///       ),
///       ColumnaTabla(
///         titulo: 'Abreviatura',
///         constructor: (u) => Text(u.abreviatura),
///       ),
///       ColumnaTabla(
///         titulo: 'Uso típico',
///         flex: 3,
///         constructor: (u) => Text(u.descripcion ?? '—'),
///       ),
///     ],
///   ),
/// )
/// ```
class TablaGenerica<T> extends StatelessWidget {
  const TablaGenerica({
    super.key,
    required this.columnas,
    required this.items,
    this.alPresionarFila,
    this.itemSeleccionado,
    this.mensajeVacio,
  });

  final List<ColumnaTabla<T>> columnas;
  final List<T> items;
  final ValueChanged<T>? alPresionarFila;
  final T? itemSeleccionado;
  final String? mensajeVacio;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ColoresApp.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Encabezado fijo: queda fuera del área scrolleable.
          _Encabezado<T>(columnas: columnas),
          const Divider(color: ColoresApp.border, height: 1, thickness: 1),
          Expanded(
            child: items.isEmpty ? _vacio() : _filas(),
          ),
        ],
      ),
    );
  }

  // Sin `Scrollbar` explícito: en escritorio `MaterialScrollBehavior` ya la
  // añade con el controller correcto. Envolverla a mano, sin controller,
  // revienta al hacer hover porque cae en el PrimaryScrollController vacío.
  Widget _filas() {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(
        color: ColoresApp.borderFila,
        height: 1,
        thickness: 1,
      ),
      itemBuilder: (context, i) => FilaTabla<T>(
        item: items[i],
        columnas: columnas,
        seleccionada: items[i] == itemSeleccionado,
        alPresionar: alPresionarFila == null
            ? null
            : () => alPresionarFila!(items[i]),
      ),
    );
  }

  Widget _vacio() {
    if (mensajeVacio == null) return const SizedBox.shrink();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(mensajeVacio!, style: TipografiaApp.caption),
      ),
    );
  }
}

class _Encabezado<T> extends StatelessWidget {
  const _Encabezado({required this.columnas});

  final List<ColumnaTabla<T>> columnas;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ColoresApp.bgInput,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
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
