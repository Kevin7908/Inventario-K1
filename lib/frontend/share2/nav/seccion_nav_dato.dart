import 'item_nav_dato.dart';

/// Datos de una sección del sidebar con su lista de ítems.
///
/// Ejemplo:
/// ```dart
/// SeccionNavDato(
///   titulo: 'Principal',
///   items: [
///     ItemNavDato(icono: Icons.dashboard_outlined, etiqueta: 'Dashboard', ...),
///   ],
/// )
/// ```
class SeccionNavDato {
  const SeccionNavDato({
    required this.titulo,
    required this.items,
  });

  final String titulo;
  final List<ItemNavDato> items;
}
