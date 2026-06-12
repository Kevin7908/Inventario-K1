import 'package:flutter/material.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import '../../../../../backend/features/reservas/modelo/reserva_abono.dart';
import 'card_info_general_reserva_widget.dart';

class CardAbonosReservaWidget extends StatelessWidget {
  const CardAbonosReservaWidget({super.key, required this.abonos});

  final List<ReservaAbono> abonos;

  @override
  Widget build(BuildContext context) {
    return CardSeccionReserva(
      titulo: 'Historial de abonos',
      trailing: Text(
        '${abonos.length} registro${abonos.length != 1 ? 's' : ''}',
        style: const TextStyle(fontSize: 11, color: ColoresApp.textLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: abonos.isEmpty
            ? const _SinAbonos()
            : Column(
                children: abonos.map((a) => _FilaAbono(abono: a)).toList(),
              ),
      ),
    );
  }
}

class _SinAbonos extends StatelessWidget {
  const _SinAbonos();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          'Sin abonos registrados aún',
          style: TextStyle(fontSize: 12, color: ColoresApp.textLight),
        ),
      ),
    );
  }
}

class _FilaAbono extends StatelessWidget {
  const _FilaAbono({required this.abono});

  final ReservaAbono abono;

  String get _fechaFormateada {
    final d = abono.fechaPago;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                  abono.monto.toCopString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.textDark,
                  ),
                ),
                Text(
                  '$_fechaFormateada'
                  '${abono.referenciaPago != null ? ' · ${abono.referenciaPago}' : ''}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: ColoresApp.textMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ChipMetodo(metodo: abono.metodoPago),
          const SizedBox(width: 8),
          Text(
            abono.monto.toCopString(),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: ColoresApp.statusPaid,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
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
