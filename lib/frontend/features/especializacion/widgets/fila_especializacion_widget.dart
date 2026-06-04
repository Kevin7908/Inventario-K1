import 'package:flutter/material.dart';

import '../../../../backend/features/especializacion/modelo/especializacion.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/botones/accion_boton.dart';

class FilaEspecializacion extends StatefulWidget {
  const FilaEspecializacion({
    super.key,
    required this.especializacion,
    required this.indice,
    required this.alEditar,
    required this.alEliminar,
  });

  final Especializacion especializacion;
  final int indice;
  final VoidCallback alEditar;
  final VoidCallback alEliminar;

  @override
  State<FilaEspecializacion> createState() => _FilaEspecializacionState();
}

class _FilaEspecializacionState extends State<FilaEspecializacion> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.especializacion;

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovering = true),
        onExit:  (_) => setState(() => _hovering = false),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: ColoresApp.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hovering ? ColoresApp.primary : ColoresApp.border,
                width: _hovering ? 1.5 : 1.0,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Número simple 
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${widget.indice + 1}',
                      style: const TextStyle(
                        color: ColoresApp.accentBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
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
                          e.nombre,
                          style: const TextStyle(
                            color: ColoresApp.textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (e.descripcion != null &&
                            e.descripcion!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            e.descripcion!,
                            style: const TextStyle(
                              color: ColoresApp.textLight,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Acciones
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AccionBoton(
                        icono: Icons.edit_outlined,
                        alPresionar: widget.alEditar,
                        tooltip: 'Editar',
                      ),
                      const SizedBox(width: 6),
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
      ),
    );
  }
}