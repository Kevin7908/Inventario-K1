import 'package:flutter/material.dart';
import 'package:inventario_k1/backend/features/deudores/modelo/deudor_resumen.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import '../detalle/badge_estado_deudor_widget.dart';

class TarjetaListaDeudorWidget extends StatelessWidget {
  const TarjetaListaDeudorWidget({
    super.key,
    required this.deudor,
    required this.seleccionado,
    required this.onTap,
  });

  final DeudorResumen deudor;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: seleccionado ? ColoresApp.primaryLight : ColoresApp.bgCard,
          border: Border(
            left: BorderSide(
              color: seleccionado ? ColoresApp.primary : Colors.transparent,
              width: 3,
            ),
            bottom: const BorderSide(color: ColoresApp.border),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(11, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilaNumeroSaldo(deudor: deudor, seleccionado: seleccionado),
            const SizedBox(height: 5),
            _FilaClienteEstado(deudor: deudor),
            const SizedBox(height: 4),
            _ConceptoTruncado(concepto: deudor.concepto),
            const SizedBox(height: 8),
            _BarraPago(deudor: deudor),
          ],
        ),
      ),
    );
  }
}

class _FilaNumeroSaldo extends StatelessWidget {
  const _FilaNumeroSaldo({required this.deudor, required this.seleccionado});

  final DeudorResumen deudor;
  final bool seleccionado;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          deudor.numero,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: seleccionado ? ColoresApp.primaryDark : ColoresApp.primary,
            letterSpacing: 0.3,
          ),
        ),
        const Spacer(),
        Text(
          deudor.saldo.toCopString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: deudor.saldo > 0
                ? ColoresApp.textDark
                : ColoresApp.statusPaid,
          ),
        ),
      ],
    );
  }
}

class _FilaClienteEstado extends StatelessWidget {
  const _FilaClienteEstado({required this.deudor});

  final DeudorResumen deudor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            deudor.nombreCliente,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ColoresApp.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        BadgeEstadoDeudorWidget(estado: deudor.estado),
      ],
    );
  }
}

class _ConceptoTruncado extends StatelessWidget {
  const _ConceptoTruncado({required this.concepto});

  final String concepto;

  @override
  Widget build(BuildContext context) {
    return Text(
      concepto,
      style: const TextStyle(fontSize: 12, color: ColoresApp.textMedium),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _BarraPago extends StatelessWidget {
  const _BarraPago({required this.deudor});

  final DeudorResumen deudor;

  Color get _colorBarra {
    if (deudor.porcentajePagado >= 1.0) return ColoresApp.statusPaid;
    if (deudor.estaVencida) return ColoresApp.statusPending;
    return ColoresApp.primary;
  }

  @override
  Widget build(BuildContext context) {
    final pct = deudor.porcentajePagado;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 4,
            backgroundColor: ColoresApp.border,
            valueColor: AlwaysStoppedAnimation<Color>(_colorBarra),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${deudor.montoPagado.toCopString()} pagado',
              style: const TextStyle(
                fontSize: 11,
                color: ColoresApp.textLight,
              ),
            ),
            Text(
              '${(pct * 100).toStringAsFixed(0)}% · ${deudor.montoTotal.toCopString()}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ColoresApp.textLight,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
