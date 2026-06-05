import 'package:flutter/material.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

class TotalesFormularioReservaWidget extends StatelessWidget {
  const TotalesFormularioReservaWidget({
    super.key,
    required this.total,
    required this.abonoInicial,
    required this.saldo,
    required this.esEdicion,
  });

  final int total;
  final int abonoInicial;
  final int saldo;
  final bool esEdicion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _FilaTotales(label: 'Total productos', valor: total.toCopString()),
          if (!esEdicion) ...[
            const SizedBox(height: 6),
            _FilaTotales(
                label: 'Abono inicial', valor: abonoInicial.toCopString()),
            const SizedBox(height: 6),
            _FilaTotales(
              label: 'Saldo pendiente',
              valor: saldo.toCopString(),
              colorValor: saldo > 0 ? ColoresApp.statusDebt : null,
            ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1, color: ColoresApp.border),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total reserva',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ColoresApp.textDark,
                ),
              ),
              Text(
                total.toCopString(),
                style: const TextStyle(
                  fontSize: 24,
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

class _FilaTotales extends StatelessWidget {
  const _FilaTotales({
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
