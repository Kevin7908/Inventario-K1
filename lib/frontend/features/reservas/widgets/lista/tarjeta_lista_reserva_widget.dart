import 'package:inventario_k1/core/formato.dart';
import 'package:flutter/material.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import '../../../../../backend/features/reservas/modelo/reserva_resumen.dart';
import '../detalle/badge_estado_reserva_widget.dart';

class TarjetaListaReservaWidget extends StatelessWidget {
  const TarjetaListaReservaWidget({
    super.key,
    required this.reserva,
    required this.seleccionada,
    required this.onTap,
  });

  final ReservaResumen reserva;
  final bool seleccionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: seleccionada ? ColoresApp.primaryLight : ColoresApp.bgCard,
          border: Border(
            left: BorderSide(
              color: seleccionada ? ColoresApp.primary : Colors.transparent,
              width: 3,
            ),
            bottom: const BorderSide(color: ColoresApp.border),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(11, 11, 12, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Fila1(reserva: reserva, seleccionada: seleccionada),
            const SizedBox(height: 5),
            _Fila2(reserva: reserva),
            const SizedBox(height: 6),
            _BarraPago(reserva: reserva),
          ],
        ),
      ),
    );
  }
}

class _Fila1 extends StatelessWidget {
  const _Fila1({required this.reserva, required this.seleccionada});

  final ReservaResumen reserva;
  final bool seleccionada;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          reserva.numero,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: seleccionada ? ColoresApp.primaryDark : ColoresApp.primary,
            fontFamily: 'monospace',
          ),
        ),
        const Spacer(),
        if (reserva.estaVencida)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.warning_amber_rounded,
                size: 13, color: ColoresApp.statusDebt),
          ),
        Text(
          reserva.fechaLimite == null
              ? '—'
              : formatearFecha(reserva.fechaLimite!),
          style: TextStyle(
            fontSize: 10,
            color: reserva.estaVencida
                ? ColoresApp.statusDebt
                : ColoresApp.textLight,
            fontWeight:
                reserva.estaVencida ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _Fila2 extends StatelessWidget {
  const _Fila2({required this.reserva});

  final ReservaResumen reserva;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reserva.nombreCliente,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: ColoresApp.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (reserva.nombreMoto != null)
                Text(
                  '🏍 ${reserva.nombreMoto}'
                  '${reserva.placaMoto != null ? ' · ${reserva.placaMoto}' : ''}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: ColoresApp.textMedium,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        BadgeEstadoReservaWidget(estado: reserva.estado),
      ],
    );
  }
}

class _BarraPago extends StatelessWidget {
  const _BarraPago({required this.reserva});

  final ReservaResumen reserva;

  Color get _colorBarra {
    if (reserva.porcentajePagado >= 1.0) return ColoresApp.statusPaid;
    if (reserva.porcentajePagado > 0) return ColoresApp.statusPending;
    return ColoresApp.statusDebt;
  }

  @override
  Widget build(BuildContext context) {
    final pct = reserva.porcentajePagado;
    final pctStr =
        '${(pct * 100).toStringAsFixed(0)}% · ${reserva.totalReserva.toCopString()}';

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 5,
            backgroundColor: ColoresApp.border,
            valueColor: AlwaysStoppedAnimation<Color>(_colorBarra),
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${reserva.pagadoAcumulado.toCopString()} pagado',
              style: const TextStyle(
                fontSize: 9.5,
                color: ColoresApp.textLight,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              pctStr,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: ColoresApp.textLight,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
