import 'package:flutter/material.dart';

import '../../../../backend/features/unidades_medida/modelo/unidad_medida.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/botones/accion_boton.dart';
import 'badge_abreviatura_widget.dart';
import 'badge_tipo_widget.dart';

class FilaUnidadMedidaWidget extends StatefulWidget {
  const FilaUnidadMedidaWidget({
    super.key,
    required this.unidad,
    this.alEditar,
    this.alEliminar,
  });

  final UnidadMedida unidad;
  final VoidCallback? alEditar;
  final VoidCallback? alEliminar;

  @override
  State<FilaUnidadMedidaWidget> createState() =>
      _FilaUnidadMedidaWidgetState();
}

class _FilaUnidadMedidaWidgetState extends State<FilaUnidadMedidaWidget> {
  bool _hovering = false;

  static const _azul = ColoresApp.primary;

  late final String _tipoCapitalizado = widget.unidad.tipo.isNotEmpty
      ? widget.unidad.tipo[0].toUpperCase() + widget.unidad.tipo.substring(1)
      : '';

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
                    Icons.straighten_outlined,
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
                        widget.unidad.nombre,
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
                        widget.unidad.descripcion ?? 'Sin descripción',
                        style: TextStyle(
                          color: widget.unidad.descripcion != null
                              ? ColoresApp.textMedium
                              : ColoresApp.textLight,
                          fontSize: 12,
                          fontStyle: widget.unidad.descripcion != null
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

                BadgeAbreviaturaWidget(abreviatura: widget.unidad.abreviatura),
                const SizedBox(width: 8),

                BadgeTipo(tipo: _tipoCapitalizado, color: _azul),
                const SizedBox(width: 10),

                // Botones de acción
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
