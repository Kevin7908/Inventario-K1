// frontend/features/unidades_medida/widgets/fila_unidad_medida_widget.dart

import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/features/unidades_medida/widgets/badge_abreviatura_widget.dart';
import 'package:inventario_k1/frontend/features/unidades_medida/widgets/badge_tipo_widget.dart';

import '../../../../backend/features/unidades_medida/modelo/unidad_medida.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/botones/accion_boton.dart';

const Map<String, IconData> _iconosTipoMapa = {
  'peso':     Icons.scale_outlined,
  'volumen':  Icons.water_drop_outlined,
  'longitud': Icons.straighten_outlined,
  'area':     Icons.square_foot_outlined,
  'tiempo':   Icons.timer_outlined,
  'unidad':   Icons.tag_outlined,
  'otro':     Icons.category_outlined,
};

const Map<String, Color> _coloresTipoMapa = {
  'peso':     ColoresApp.accentAmber,
  'volumen':  ColoresApp.accentBlue,
  'longitud': ColoresApp.accentTeal,
  'area':     ColoresApp.accentGreen,
  'tiempo':   ColoresApp.accentPurple,
  'unidad':   ColoresApp.primary,
  'otro':     ColoresApp.accentOrange,
};

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

  // Cache: calculados UNA vez, no en cada rebuild
  late final Color _color =
      _coloresTipoMapa[widget.unidad.tipo] ?? ColoresApp.primary;
  late final Color _colorFondo = _color.withOpacity(0.10);
  late final IconData _icono =
      _iconosTipoMapa[widget.unidad.tipo] ?? Icons.tag_outlined;
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
                  icono: _icono,
                  color: _color,
                  fondo: _colorFondo,
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

                // Badge abreviatura 
                BadgeAbreviaturaWidget(abreviatura: widget.unidad.abreviatura),
                const SizedBox(width: 8),

                // Badge tipo
                BadgeTipo(tipo: _tipoCapitalizado, color: _color),
                const SizedBox(width: 10),

                // Botones de acción
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

// Sub-widgets privados const
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