import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/backend/features/deudores/enum/enum_deudor.dart';
import 'package:inventario_k1/backend/features/deudores/modelo/deudor_resumen.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/widgets/output/snack_bar_mensaje.dart';

import '../../provider/deudores_provider.dart';

class PanelResumenFinancieroDeudorWidget extends ConsumerWidget {
  const PanelResumenFinancieroDeudorWidget({
    super.key,
    required this.resumen,
  });

  final DeudorResumen resumen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _TarjetaFinanciera(resumen: resumen),
        const SizedBox(height: 10),
        _AccionesEstado(resumen: resumen),
      ],
    );
  }
}

class _TarjetaFinanciera extends StatelessWidget {
  const _TarjetaFinanciera({required this.resumen});

  final DeudorResumen resumen;

  Color get _colorBarra {
    if (resumen.porcentajePagado >= 1.0) return ColoresApp.statusPaid;
    if (resumen.estaVencida) return ColoresApp.statusPending;
    return ColoresApp.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: ColoresApp.bgContent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'RESUMEN FINANCIERO',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: ColoresApp.textLight,
                letterSpacing: 0.7,
              ),
            ),
          ),
          _FilaFinanciera(
            label: 'Monto total',
            valor: resumen.montoTotal.toCopString(),
          ),
          const SizedBox(height: 8),
          _FilaFinanciera(
            label: 'Pagado',
            valor: resumen.montoPagado.toCopString(),
            colorValor: ColoresApp.statusPaid,
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: ColoresApp.border),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: resumen.porcentajePagado,
              minHeight: 8,
              backgroundColor: ColoresApp.border,
              valueColor: AlwaysStoppedAnimation<Color>(_colorBarra),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${(resumen.porcentajePagado * 100).toStringAsFixed(0)}% pagado',
            style: const TextStyle(
              fontSize: 11,
              color: ColoresApp.textMedium,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: ColoresApp.border),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Saldo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ColoresApp.textDark,
                ),
              ),
              Text(
                resumen.saldo.toCopString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: resumen.saldo > 0
                      ? ColoresApp.primary
                      : ColoresApp.statusPaid,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilaFinanciera extends StatelessWidget {
  const _FilaFinanciera({
    required this.label,
    required this.valor,
    this.colorValor,
  });

  final String label;
  final String valor;
  final Color? colorValor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: ColoresApp.textMedium),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colorValor ?? ColoresApp.textDark,
          ),
        ),
      ],
    );
  }
}

class _AccionesEstado extends ConsumerWidget {
  const _AccionesEstado({required this.resumen});

  final DeudorResumen resumen;

  bool get _puedeRegistrarPago =>
      resumen.estado == EstadoDeudor.activa ||
      resumen.estado == EstadoDeudor.vencida;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.border),
      ),
      child: Column(
        children: [
          if (_puedeRegistrarPago) ...[
            _BotonAccion(
              label: 'Marcar incobrable',
              icono: Icons.block_outlined,
              color: ColoresApp.statusDebt,
              bgColor: ColoresApp.statusDebtBg,
              onTap: () =>
                  _cambiarEstado(context, ref, EstadoDeudor.incobrable),
            ),
          ],
          if (!_puedeRegistrarPago && resumen.estado != EstadoDeudor.pagada) ...[
            Text(
              'Estado: ${resumen.estado.valor.toLowerCase()}',
              style: const TextStyle(fontSize: 13, color: ColoresApp.textLight),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _cambiarEstado(
    BuildContext context,
    WidgetRef ref,
    EstadoDeudor nuevoEstado,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Cambiar a ${nuevoEstado.valor.toLowerCase()}'),
        content: const Text(
          'Se marcará como incobrable. Esta acción es reversible.',
        ),
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
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;
    final error = await ref
        .read(deudoresProvider.notifier)
        .cambiarEstado(resumen.id, nuevoEstado);
    if (!context.mounted) return;
    if (error != null) {
      SnackBarMensaje.error(context, error);
    } else {
      SnackBarMensaje.success(
          context, 'Estado actualizado a ${nuevoEstado.valor}.');
    }
  }
}

class _BotonAccion extends StatelessWidget {
  const _BotonAccion({
    required this.label,
    required this.icono,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  final String label;
  final IconData icono;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icono, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
