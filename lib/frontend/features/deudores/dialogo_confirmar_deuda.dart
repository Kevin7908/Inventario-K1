import 'package:flutter/material.dart';

import '../../share/formateadores/moneda_formateador.dart';
import '../../share/temas/colores_app.dart';

const _kBlue  = ColoresApp.primary;
const _kGreen = ColoresApp.accentGreen;
const _kAmber = ColoresApp.accentAmber;

/// Diálogo que resume la deuda a registrar y pide confirmación.
/// Retorna true si el usuario confirma, false/null si cancela.
class DialogoConfirmarDeuda extends StatelessWidget {
  const DialogoConfirmarDeuda._({
    required this.clienteNombre,
    required this.total,
    required this.recibido,
    required this.faltante,
  });

  final String clienteNombre;
  final double total;
  final double recibido;
  final double faltante;

  static Future<bool?> mostrar(
    BuildContext context, {
    required String clienteNombre,
    required double total,
    required double recibido,
    required double faltante,
  }) =>
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => DialogoConfirmarDeuda._(
          clienteNombre: clienteNombre,
          total:         total,
          recibido:      recibido,
          faltante:      faltante,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Título ────────────────────────────────────────────────
              const Text(
                'Registrar deuda pendiente',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'El cliente no cubrió el monto completo.',
                style: TextStyle(fontSize: 13, color: ColoresApp.textMedium),
              ),
              const SizedBox(height: 20),

              // ── Tarjeta resumen ───────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: ColoresApp.bgContent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ColoresApp.border),
                ),
                child: Column(
                  children: [
                    _FilaResumen(
                      label:      'Cliente',
                      valor:      clienteNombre,
                      valorBold:  true,
                      valorColor: _kBlue,
                    ),
                    const Divider(height: 1, color: ColoresApp.border),
                    _FilaResumen(
                      label: 'Total factura',
                      valor: fmtMoneda(total),
                    ),
                    const Divider(height: 1, color: ColoresApp.border),
                    _FilaResumen(
                      label:      'Recibido',
                      valor:      fmtMoneda(recibido),
                      valorColor: _kGreen,
                    ),
                    const Divider(height: 1, color: ColoresApp.border),
                    _FilaResumen(
                      label:      'Deuda pendiente',
                      valor:      fmtMoneda(faltante),
                      valorBold:  true,
                      valorColor: _kAmber,
                      fondo:      _kAmber.withValues(alpha: 0.05),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Nota ─────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: _kAmber.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kAmber.withValues(alpha: 0.20)),
                ),
                child: const Text(
                  'La factura quedará en estado Pendiente hasta que se salde la deuda.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kAmber,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // ── Botones ───────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ColoresApp.textMedium,
                        side: const BorderSide(color: ColoresApp.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9)),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9)),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Confirmar deuda'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaResumen extends StatelessWidget {
  const _FilaResumen({
    required this.label,
    required this.valor,
    this.valorColor,
    this.valorBold = false,
    this.fondo,
  });

  final String label;
  final String valor;
  final Color? valorColor;
  final bool   valorBold;
  final Color? fondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: fondo,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 13, color: ColoresApp.textMedium),
          ),
          const Spacer(),
          Text(
            valor,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: valorBold ? FontWeight.w700 : FontWeight.w500,
              color: valorColor ?? ColoresApp.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
