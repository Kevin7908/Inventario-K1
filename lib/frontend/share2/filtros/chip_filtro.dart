import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Chip que activa o desactiva un filtro de una lista.
///
/// Se usa en grupos (normalmente dentro de un `Wrap`) para filtrar una
/// colección por categoría, estado o cualquier criterio de una sola dimensión.
/// El widget no decide nada: recibe [seleccionado] ya resuelto y avisa por
/// [alPresionar].
///
/// Parámetros:
/// - [etiqueta]: texto del chip.
/// - [seleccionado]: si está activo. Cambia a fondo oscuro y texto blanco.
/// - [alPresionar]: callback al hacer tap.
/// - [icono]: ícono opcional a la izquierda del texto.
/// - [colorActivo]: fondo cuando está seleccionado. Por defecto
///   `ColoresApp.blackChocolate`.
///
/// Ejemplo:
/// ```dart
/// Wrap(
///   spacing: 9,
///   children: [
///     ChipFiltro(
///       etiqueta: 'Todas',
///       seleccionado: categoriaActiva == null,
///       alPresionar: () => controlador.filtrarPorCategoria(null),
///     ),
///     for (final c in categorias)
///       ChipFiltro(
///         etiqueta: c.nombre,
///         seleccionado: categoriaActiva == c.id,
///         alPresionar: () => controlador.filtrarPorCategoria(c.id),
///       ),
///   ],
/// )
/// ```
class ChipFiltro extends StatelessWidget {
  const ChipFiltro({
    super.key,
    required this.etiqueta,
    required this.seleccionado,
    required this.alPresionar,
    this.icono,
    this.colorActivo,
  });

  final String etiqueta;
  final bool seleccionado;
  final VoidCallback alPresionar;
  final IconData? icono;
  final Color? colorActivo;

  @override
  Widget build(BuildContext context) {
    final Color activo = colorActivo ?? ColoresApp.blackChocolate;
    final Color fondo = seleccionado ? activo : ColoresApp.bgCard;
    final Color contenido =
        seleccionado ? ColoresApp.textOnPrimary : ColoresApp.textSecondary;
    final Color borde = seleccionado ? activo : ColoresApp.border;

    return Material(
      color: fondo,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: alPresionar,
        borderRadius: BorderRadius.circular(11),
        hoverColor: seleccionado
            ? Colors.white.withValues(alpha: 0.08)
            : ColoresApp.bgCardHover,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: borde),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icono != null) ...[
                Icon(icono, size: 15, color: contenido),
                const SizedBox(width: 8),
              ],
              Text(
                etiqueta,
                style: TipografiaApp.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: contenido,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
