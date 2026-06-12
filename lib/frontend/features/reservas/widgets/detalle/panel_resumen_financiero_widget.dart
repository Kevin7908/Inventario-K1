import 'package:flutter/material.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import '../../../../../backend/features/reservas/enum/enum_reserva.dart';
import '../../../../../backend/features/reservas/modelo/reserva_resumen.dart';

class PanelResumenFinancieroWidget extends StatelessWidget {
  const PanelResumenFinancieroWidget({
    super.key,
    required this.resumen,
    required this.onCancelar,
  });

  final ReservaResumen resumen;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TarjetaFinanciera(resumen: resumen),
        const SizedBox(height: 10),
        _AccionesEstado(
          estado: resumen.estado,
          onCancelar: onCancelar,
        ),
      ],
    );
  }
}

class _TarjetaFinanciera extends StatelessWidget {
  const _TarjetaFinanciera({required this.resumen});

  final ReservaResumen resumen;

  Color get _colorBarra {
    if (resumen.porcentajePagado >= 1.0) return ColoresApp.statusPaid;
    if (resumen.porcentajePagado > 0) return ColoresApp.statusPending;
    return ColoresApp.statusDebt;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _FilaFinanciera(
            label: 'Total reserva',
            valor: resumen.totalReserva.toCopString(),
          ),
          const SizedBox(height: 6),
          _FilaFinanciera(
            label: 'Pagado',
            valor: resumen.pagadoAcumulado.toCopString(),
            colorValor: ColoresApp.statusPaid,
          ),
          const SizedBox(height: 6),
          _FilaFinanciera(
            label: 'Saldo pendiente',
            valor: resumen.saldo.toCopString(),
            colorValor: resumen.saldo > 0 ? ColoresApp.statusDebt : null,
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: ColoresApp.border),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: resumen.porcentajePagado,
              minHeight: 8,
              backgroundColor: ColoresApp.border,
              valueColor: AlwaysStoppedAnimation<Color>(_colorBarra),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${(resumen.porcentajePagado * 100).toStringAsFixed(0)}% pagado',
              style: const TextStyle(
                fontSize: 11,
                color: ColoresApp.textMedium,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: ColoresApp.border),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ColoresApp.textDark,
                ),
              ),
              Text(
                resumen.totalReserva.toCopString(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: ColoresApp.primary,
                  fontFamily: 'monospace',
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
          style: const TextStyle(
            fontSize: 12.5,
            color: ColoresApp.textMedium,
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: colorValor ?? ColoresApp.textDark,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _AccionesEstado extends StatelessWidget {
  const _AccionesEstado({
    required this.estado,
    required this.onCancelar,
  });

  final EstadoReserva estado;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    if (estado != EstadoReserva.activa) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        child: Text(
          'Esta reserva está ${estado.valor.toLowerCase()}',
          style: const TextStyle(
            fontSize: 12,
            color: ColoresApp.textLight,
          ),
        ),
      );
    }

    return _BotonAccion(
      label: 'Cancelar reserva',
      icono: Icons.cancel_outlined,
      color: ColoresApp.statusDebt,
      bgColor: ColoresApp.statusDebtBg,
      onTap: onCancelar,
    );
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
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icono, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: color,
          side: BorderSide(color: color, width: 1.5),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
