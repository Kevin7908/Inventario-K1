import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../../backend/features/ventas/ordenes/modelo/orden_tarea.dart';
import '../../../../../../share/temas/colores_app.dart';
import '../../../../../../share/widgets/dialogos/dialogo_confirmar_eliminar_widget.dart';
import '../../../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../../provider/ordenes_provider.dart';
import '../../../widgets/dialogo_agregar_editar_tarea.dart';
import '../../helpers/formateadores.dart';
import '../detalle_shared_widgets.dart';

class TareasListaCard extends ConsumerWidget {
  const TareasListaCard({super.key, required this.ordenId});
  final int ordenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tareas = ref.watch(
      ordenDetalleProvider(ordenId).select(
        (a) => a.value?.tareas ?? const [],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          SeccionHeader(
            titulo: 'Mano de obra',
            icono: Icons.build_outlined,
            accion: TextButton.icon(
              onPressed: () => DialogoAgregarEditarTarea.mostrar(
                context,
                ordenId: ordenId,
              ),
              icon: const Icon(Icons.add_rounded, size: 14),
              label: const Text('Agregar'),
              style: TextButton.styleFrom(
                foregroundColor: ColoresApp.primary,
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (tareas.isEmpty)
            const EstadoVacioSeccion(mensaje: 'Sin tareas registradas')
          else
            Column(
              children: tareas
                  .map((t) => _FilaTarea(tarea: t, ordenId: ordenId))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _FilaTarea extends ConsumerWidget {
  const _FilaTarea({required this.tarea, required this.ordenId});
  final OrdenTarea tarea;
  final int ordenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => ref.read(ordenesProvider.notifier).actualizarTarea(
                  tarea.id,
                  ordenId,
                  completado: !tarea.completado,
                ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: tarea.completado
                    ? const Color(0xFFF0FDF4)
                    : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: tarea.completado
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFD1D5DB),
                  width: 1.5,
                ),
              ),
              child: tarea.completado
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Color(0xFF16A34A))
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tarea.servicioNombre,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.textDark,
                  ),
                ),
                Text(
                  tarea.tecnicoNombre +
                      (tarea.notas != null ? ' · "${tarea.notas}"' : ''),
                  style: const TextStyle(
                    fontSize: 12,
                    color: ColoresApp.textMedium,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            fmtMoneda(tarea.precioPactado),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ColoresApp.textDark,
            ),
          ),
          const SizedBox(width: 10),
          MiniBoton(
            icono: Icons.edit_outlined,
            color: ColoresApp.primary,
            onTap: () => DialogoAgregarEditarTarea.mostrar(
              context,
              ordenId: ordenId,
              tareaAEditar: tarea,
            ),
          ),
          const SizedBox(width: 6),
          MiniBoton(
            icono: Icons.delete_outline_rounded,
            color: ColoresApp.statusDebt,
            onTap: () => DialogoConfirmarEliminar.mostrar(
              context: context,
              nombreElemento: tarea.servicioNombre,
              tipoElemento: 'tarea',
              onConfirmar: () async {
                final error = await ref
                    .read(ordenesProvider.notifier)
                    .eliminarTarea(tarea.id, ordenId);
                if (!context.mounted) return;
                if (error != null) SnackBarMensaje.error(context, error);
              },
            ),
          ),
        ],
      ),
    );
  }
}
