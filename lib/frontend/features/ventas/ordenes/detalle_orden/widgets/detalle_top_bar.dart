import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../backend/features/ventas/ordenes/enum/enum_ordenes.dart';
import '../../../../../share/temas/colores_app.dart';
import '../../../../../share/widgets/botones/accion_boton.dart';
import '../../provider/ordenes_provider.dart';

class DetalleTopBar extends ConsumerWidget {
  const DetalleTopBar({
    super.key,
    required this.ordenId,
    required this.onVolver,
    required this.onCambiarEstado,
    required this.onEditar,
    required this.onEliminar,
  });

  final int ordenId;
  final VoidCallback onVolver;
  final ValueChanged<EstadoOrden> onCambiarEstado;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  static const _estadoColores = {
    EstadoOrden.abierta:   Color(0xFF3B82F6),
    EstadoOrden.lista:     Color(0xFF10B981),
    EstadoOrden.entregada: Color(0xFF6B7280),
    EstadoOrden.anulada:   Color(0xFFEF4444),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalle = ref.watch(ordenDetalleProvider(ordenId)).value;
    if (detalle == null) return const SizedBox.shrink();

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onVolver,
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 14, color: ColoresApp.primary),
            label: const Text(
              'Taller',
              style: TextStyle(
                color: ColoresApp.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),
          const Text(
            ' / ',
            style: TextStyle(color: ColoresApp.textLight, fontSize: 13),
          ),
          Text(
            detalle.numeroOrden,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ColoresApp.textDark,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: ColoresApp.bgContent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ColoresApp.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<EstadoOrden>(
                value: detalle.estado,
                isDense: true,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'DM Sans',
                ),
                items: EstadoOrden.values.map((e) {
                  final color = _estadoColores[e]!;
                  return DropdownMenuItem(
                    value: e,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          e.etiqueta,
                          style: TextStyle(color: color),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (e) {
                  if (e != null && e != detalle.estado) onCambiarEstado(e);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onEditar,
            icon: const Icon(Icons.edit_outlined, size: 14),
            label: const Text('Editar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ColoresApp.primary,
              side: BorderSide(color: ColoresApp.primary.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AccionBoton(
            icono: Icons.delete_outline_rounded,
            tooltip: 'Eliminar orden',
            esDestructivo: true,
            alPresionar: onEliminar,
          ),
        ],
      ),
    );
  }
}
