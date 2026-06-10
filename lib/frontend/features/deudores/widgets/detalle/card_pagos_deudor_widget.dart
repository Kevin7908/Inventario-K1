import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/backend/features/deudores/modelo/deudor_pago.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/widgets/output/snack_bar_mensaje.dart';

import '../../provider/deudores_provider.dart';
import 'card_info_general_deudor_widget.dart';

class CardPagosDeudorWidget extends ConsumerWidget {
  const CardPagosDeudorWidget({
    super.key,
    required this.pagos,
    required this.deudorId,
  });

  final List<DeudorPago> pagos;
  final int deudorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CardSeccionDeudor(
      titulo: 'Historial de pagos',
      trailing: Text(
        '${pagos.length} registro${pagos.length != 1 ? 's' : ''}',
        style: const TextStyle(fontSize: 11, color: ColoresApp.textLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: pagos.isEmpty
            ? const _SinPagos()
            : Column(
                children: pagos
                    .map((p) => _FilaPago(
                          pago: p,
                          deudorId: deudorId,
                        ))
                    .toList(),
              ),
      ),
    );
  }
}

class _SinPagos extends StatelessWidget {
  const _SinPagos();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          'Sin pagos registrados aún',
          style: TextStyle(fontSize: 12, color: ColoresApp.textLight),
        ),
      ),
    );
  }
}

class _FilaPago extends ConsumerWidget {
  const _FilaPago({required this.pago, required this.deudorId});

  final DeudorPago pago;
  final int deudorId;

  String get _fechaFormateada {
    final d = pago.fechaPago;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: ColoresApp.statusPaidBg,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.credit_card_rounded,
              size: 16,
              color: ColoresApp.statusPaid,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fechaFormateada,
                  style: const TextStyle(
                    fontSize: 10,
                    color: ColoresApp.textMedium,
                    fontFamily: 'monospace',
                  ),
                ),
                if (pago.notas != null && pago.notas!.isNotEmpty)
                  Text(
                    pago.notas!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: ColoresApp.textLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ChipMetodo(metodo: pago.metodoPago),
          const SizedBox(width: 10),
          Text(
            pago.monto.toCopString(),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: ColoresApp.statusPaid,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 6),
          _BotonEliminarPago(
            onTap: () => _confirmarEliminar(context, ref),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminar(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar pago'),
        content:
            Text('¿Eliminar el pago de ${pago.monto.toCopString()}? El saldo se recalculará.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColoresApp.statusDebt,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    ).then((confirmado) async {
      if (confirmado != true || !context.mounted) return;
      final error = await ref
          .read(deudoresProvider.notifier)
          .eliminarPago(pago.id, deudorId);
      if (!context.mounted) return;
      if (error != null) {
        SnackBarMensaje.error(context, error);
      } else {
        SnackBarMensaje.success(context, 'Pago eliminado.');
      }
    });
  }
}

class _ChipMetodo extends StatelessWidget {
  const _ChipMetodo({required this.metodo});

  final String metodo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: ColoresApp.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        metodo,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: ColoresApp.primary,
        ),
      ),
    );
  }
}

class _BotonEliminarPago extends StatelessWidget {
  const _BotonEliminarPago({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: ColoresApp.statusDebtBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          size: 14,
          color: ColoresApp.statusDebt,
        ),
      ),
    );
  }
}
