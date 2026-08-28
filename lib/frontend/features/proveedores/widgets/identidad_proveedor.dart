import 'package:flutter/material.dart';

import '../../../share/share.dart';

/// Cómo se pinta un proveedor en toda la app.
///
/// Un almacén y el color de la aplicación, iguales para todos, por lo mismo
/// que en [IdentidadCategoria]: la apariencia es cosa de la vista, no un dato
/// que se guarde por proveedor.
///
/// Ejemplo:
/// ```dart
/// MarcadorIdentidad(
///   icono: IdentidadProveedor.icono,
///   color: IdentidadProveedor.color,
/// )
/// ```
final class IdentidadProveedor {
  const IdentidadProveedor._();

  static const Color color = ColoresApp.goGreen;

  /// El almacén: es lo que un proveedor es para el taller.
  static const IconData icono = Icons.warehouse_outlined;
}
