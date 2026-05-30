import 'package:flutter/material.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

class CotTotalesResumen extends StatelessWidget {
  const CotTotalesResumen({
    super.key,
    required this.subtotal,
    required this.iva,
    required this.total,
  });

  final int subtotal;
  final int iva;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.border),
      ),
      child: Column(
        children: [
          CotFilaTotal(label: 'Subtotal', valor: subtotal),
          const SizedBox(height: 6),
          CotFilaTotal(label: 'IVA (19%)', valor: iva),
          const Divider(height: 16, color: ColoresApp.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  color: ColoresApp.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                total.toCopString(),
                style: const TextStyle(
                  color: ColoresApp.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CotFilaTotal extends StatelessWidget {
  const CotFilaTotal({super.key, required this.label, required this.valor});

  final String label;
  final int valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: ColoresApp.textMedium, fontSize: 13),
        ),
        Text(
          valor.toCopString(),
          style: const TextStyle(color: ColoresApp.textDark, fontSize: 13),
        ),
      ],
    );
  }
}
