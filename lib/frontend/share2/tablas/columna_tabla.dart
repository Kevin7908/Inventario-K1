import 'package:flutter/widgets.dart';

/// Define una columna de [TablaGenerica]: encabezado, ancho y builder de celda.
///
/// Parámetros:
/// - [titulo]: texto del encabezado de la columna. Se muestra en mayúsculas.
/// - [constructor]: recibe el ítem de la fila y devuelve el widget de la celda.
/// - [flex]: peso relativo del ancho de la columna. Se ignora si se define [ancho].
/// - [ancho]: ancho fijo en píxeles. Si es `null`, la columna usa [flex].
/// - [alineacion]: alineación del contenido dentro de la celda.
///
/// Ejemplo:
/// ```dart
/// ColumnaTabla<UnidadMedida>(
///   titulo: 'Unidad',
///   flex: 2,
///   constructor: (unidad) => Text(unidad.nombre),
/// )
/// ```
class ColumnaTabla<T> {
  const ColumnaTabla({
    required this.titulo,
    required this.constructor,
    this.flex = 1,
    this.ancho,
    this.alineacion = Alignment.centerLeft,
  });

  final String titulo;
  final Widget Function(T item) constructor;
  final int flex;
  final double? ancho;
  final AlignmentGeometry alineacion;
}
