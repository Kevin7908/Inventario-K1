import 'package:flutter/material.dart';

import '../../../../backend/features/categorias/modelo/categoria.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/botones/accion_boton.dart';

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

  static const _azul = ColoresApp.primary;

  @override
  Widget build(BuildContext context) {
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
              color: _hovering ? _azul.withOpacity(0.45) : ColoresApp.border,
              width: _hovering ? 1.5 : 1.0,
            ),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: _azul.withOpacity(0.07),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : const [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icono fijo azul
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _azul.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.layers_outlined,
                    color: _azul,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),

                // Nombre + descripción
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

                // Acciones
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AccionBoton(
                      icono: Icons.edit_outlined,
                      alPresionar: widget.alEditar,
                      tooltip: 'Editar',
                    ),
                    const SizedBox(width: 4),
                    AccionBoton(
                      icono: Icons.delete_outline_rounded,
                      alPresionar: widget.alEliminar,
                      tooltip: 'Eliminar',
                      esDestructivo: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
