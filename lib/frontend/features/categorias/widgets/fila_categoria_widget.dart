import 'package:flutter/material.dart';

import '../../../../backend/features/categorias/modelo/categoria.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/botones/accion_boton.dart';

// Mapa de íconos (top-level const para no recrearlo)
const Map<String, IconData> _iconosMapa = {
  'category': Icons.category_outlined,
  'oil_barrel': Icons.oil_barrel_outlined,
  'settings': Icons.settings_outlined,
  'electrical_services': Icons.electrical_services_outlined,
  'tire_repair': Icons.tire_repair_outlined,
  'link': Icons.link_outlined,
  'car_repair': Icons.car_repair_outlined,
  'construction': Icons.construction_outlined,
  'inventory': Icons.inventory_2_outlined,
  'build': Icons.build_outlined,
};

class FilaCategoriaWidget extends StatefulWidget {
  const FilaCategoriaWidget({
    super.key,
    required this.categoria,
    this.alEditar,
    this.alEliminar,
  });

  final Categoria categoria;
  final VoidCallback? alEditar;
  final VoidCallback? alEliminar;

  @override
  State<FilaCategoriaWidget> createState() => _FilaCategoriaWidgetState();
}

class _FilaCategoriaWidgetState extends State<FilaCategoriaWidget> {
  bool _hovering = false;

  // Cache del color para no llamar a int.parse en cada rebuild
  late final Color _color = _colorDesdeHex(widget.categoria.colorHex);
  late final Color _colorFondo = _color.withOpacity(0.10);

  static Color _colorDesdeHex(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return ColoresApp.primary;
    }
  }

  static IconData _iconoDesdeNombre(String nombre) =>
      _iconosMapa[nombre] ?? Icons.category_outlined;

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary: el AnimatedContainer solo repinta este subtree
    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: ColoresApp.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovering ? _color.withOpacity(0.55) : ColoresApp.border,
              width: _hovering ? 1.5 : 1.0,
            ),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: _color.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Ícono con fondo tintado
                _IconoBadge(
                  icono: _iconoDesdeNombre(widget.categoria.icono),
                  color: _color,
                  fondo: _colorFondo,
                ),
                const SizedBox(width: 14),

                // Textos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.categoria.nombre,
                        style: const TextStyle(
                          color: ColoresApp.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.categoria.descripcion ?? 'Sin descripción',
                        style: TextStyle(
                          color: widget.categoria.descripcion != null
                              ? ColoresApp.textMedium
                              : ColoresApp.textLight,
                          fontSize: 12,
                          fontStyle: widget.categoria.descripcion != null
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Badge de productos
                _BadgeProductos(total: widget.categoria.totalProductos),
                const SizedBox(width: 10),

                // Acciones (visibles siempre; en móvil compacto)
                _BotonesAccion(
                  alEditar: widget.alEditar,
                  alEliminar: widget.alEliminar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Sub-widgets privados

class _IconoBadge extends StatelessWidget {
  const _IconoBadge({
    required this.icono,
    required this.color,
    required this.fondo,
  });

  final IconData icono;
  final Color color;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
      child: Icon(icono, color: color, size: 20),
    );
  }
}

class _BadgeProductos extends StatelessWidget {
  const _BadgeProductos({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$total producto${total == 1 ? '' : 's'}',
        style: const TextStyle(
          color: ColoresApp.textDark,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _BotonesAccion extends StatelessWidget {
  const _BotonesAccion({this.alEditar, this.alEliminar});

  final VoidCallback? alEditar;
  final VoidCallback? alEliminar;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AccionBoton(
          icono: Icons.edit_outlined,
          alPresionar: alEditar,
          tooltip: 'Editar',
        ),
        const SizedBox(width: 4),
        AccionBoton(
          icono: Icons.delete_outline_rounded,
          alPresionar: alEliminar,
          tooltip: 'Eliminar',
          esDestructivo: true,
        ),
      ],
    );
  }
}
