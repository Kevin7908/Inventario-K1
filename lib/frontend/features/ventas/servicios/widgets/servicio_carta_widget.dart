import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/frontend/features/ventas/servicios/widgets/dialogo_servicios.dart';

import '../../../../../backend/features/ventas/servicios/modelo/servicio.dart';
import '../../../../share/temas/colores_app.dart';
import '../../../../share/widgets/dialogos/dialogo_confirmar_eliminar_widget.dart';
import '../../../../share/widgets/output/badge_estado.dart';
import '../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../provider/servicios_provider.dart';

class ServicioCartaWidget extends ConsumerWidget {
  final Servicio servicio;
  const ServicioCartaWidget({super.key, required this.servicio});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(serviciosProvider.notifier);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresApp.border),
        boxShadow: const [
          BoxShadow(color: ColoresApp.shadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icono de servicio
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ColoresApp.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.home_repair_service_outlined,
                    size: 18,
                    color: ColoresApp.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        servicio.nombre,
                        style: const TextStyle(
                          color: ColoresApp.textDark,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      BadgeEstado(activo: servicio.activo),
                    ],
                  ),
                ),
              ],
            ),

            // Descripcion 
            if (servicio.descripcion != null &&
                servicio.descripcion!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                servicio.descripcion!,
                style: const TextStyle(
                  color: ColoresApp.textMedium,
                  fontSize: 12,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const Spacer(),

            // Pie
            const Divider(color: ColoresApp.border, height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _BotonAccion(
                      icono: Icons.edit_outlined,
                      color: ColoresApp.primary,
                      tooltip: 'Editar',
                      onTap: () => DialogoServicio.mostrar(
                        context,
                        servicioAEditar: servicio,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _BotonAccion(
                      icono: Icons.delete_outline_rounded,
                      color: ColoresApp.accentRed,
                      tooltip: 'Eliminar',
                      onTap: () => DialogoConfirmarEliminar.mostrar(
                        context: context,
                        nombreElemento: servicio.nombre,
                        tipoElemento: 'servicio',
                        onConfirmar: () {
                          notifier.eliminar(servicio.id).then((error) {
                            if (!context.mounted) return;
                            if (error != null) {
                              SnackBarMensaje.error(context, error);
                            } else {
                              SnackBarMensaje.success(
                                context,
                                '"\${servicio.nombre}" eliminado correctamente.',
                              );
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonAccion extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _BotonAccion({
    required this.icono,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icono, size: 15, color: color),
        ),
      ),
    );
  }
}