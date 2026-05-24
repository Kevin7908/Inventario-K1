import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../provider/ordenes_provider.dart';
import '../detalle_shared_widgets.dart';

class DiagnosticoCard extends ConsumerWidget {
  const DiagnosticoCard({super.key, required this.ordenId});
  final int ordenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diagnostico = ref.watch(
      ordenDetalleProvider(ordenId).select(
        (a) => a.value == null
            ? null
            : (
                cliente: a.value!.diagnosticoCliente,
                mecanico: a.value!.observacionesMecanico,
              ),
      ),
    );

    if (diagnostico == null) return const SizedBox.shrink();
    if (diagnostico.cliente == null && diagnostico.mecanico == null) {
      return const SizedBox.shrink();
    }

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
          const SeccionHeader(
            titulo: 'Diagnóstico y observaciones',
            icono: Icons.info_outline_rounded,
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (diagnostico.cliente != null)
                  Expanded(
                    child: InfoCell(
                      etiqueta: 'Diagnóstico del cliente',
                      valor: diagnostico.cliente!,
                    ),
                  ),
                if (diagnostico.cliente != null && diagnostico.mecanico != null)
                  const VerticalDivider(width: 1, color: Color(0xFFE5E7EB)),
                if (diagnostico.mecanico != null)
                  Expanded(
                    child: InfoCell(
                      etiqueta: 'Observaciones del mecánico',
                      valor: diagnostico.mecanico!,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
