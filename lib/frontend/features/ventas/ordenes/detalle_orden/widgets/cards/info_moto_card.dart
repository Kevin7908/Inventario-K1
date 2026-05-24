import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../../../backend/features/ventas/ordenes/modelo/orden_detalle.dart';
import '../../../../../../share/temas/colores_app.dart';
import '../../../provider/ordenes_provider.dart';
import '../../helpers/formateadores.dart';

class InfoMotoCard extends ConsumerWidget {
  const InfoMotoCard({super.key, required this.ordenId});
  final int ordenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalle = ref.watch(
      ordenDetalleProvider(ordenId).select((a) => a.value),
    );
    if (detalle == null) return const SizedBox.shrink();

    return _MotoCardView(detalle: detalle);
  }
}

class _MotoCardView extends StatelessWidget {
  const _MotoCardView({required this.detalle});
  final OrdenDetalle detalle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ColoresApp.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.two_wheeler_rounded,
              size: 24,
              color: ColoresApp.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detalle.motoDescripcion,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${detalle.motoPlaca} · ${detalle.clienteNombre}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: ColoresApp.textMedium,
                  ),
                ),
              ],
            ),
          ),
          _BadgeInfo(
            texto: 'Km: ${NumberFormat('#,##0', 'es_CO').format(detalle.kilometrajeEntrada)}',
          ),
          if (detalle.fechaIngreso != null) ...[
            const SizedBox(width: 8),
            _BadgeInfo(texto: fmtFecha(detalle.fechaIngreso!)),
          ],
        ],
      ),
    );
  }
}

class _BadgeInfo extends StatelessWidget {
  const _BadgeInfo({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ColoresApp.border),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ColoresApp.textMedium,
        ),
      ),
    );
  }
}
