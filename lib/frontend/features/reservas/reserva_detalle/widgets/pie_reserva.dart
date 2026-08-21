import 'package:flutter/material.dart';

import '../../../../../core/formato.dart';
import '../../../../share2/share2.dart';

/// El estado de cuentas de la reserva, al pie del panel derecho.
///
/// A diferencia de [PieTotales], que habla de subtotal, descuento e IVA, este
/// habla de **deuda**: cuánto vale lo apartado, cuánto se ha entregado y
/// cuánto falta. Por eso no reutiliza aquel widget aunque se le parezca de
/// lejos: son dos preguntas distintas y el mismo bloque no puede responder las
/// dos sin volverse un formulario de banderas.
///
/// La barra repite lo que dicen las tres cifras, y está a propósito: el
/// porcentaje se lee de un vistazo desde el otro lado del mostrador, los
/// números no.
///
/// Parámetros:
/// - [total]: lo que vale la mercancía apartada.
/// - [pagado]: lo entregado hasta ahora.
/// - [alCancelar]: `null` si la reserva ya no se puede cancelar.
class PieReserva extends StatelessWidget {
  const PieReserva({
    super.key,
    required this.total,
    required this.pagado,
    this.alCancelar,
  });

  final int total;
  final int pagado;
  final VoidCallback? alCancelar;

  int get _saldo => (total - pagado).clamp(0, total);

  double get _progreso => total > 0 ? (pagado / total).clamp(0.0, 1.0) : 0.0;

  @override
  Widget build(BuildContext context) {
    final porcentaje = (_progreso * 100).round();
    final pagada = total > 0 && pagado >= total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Fila(etiqueta: 'Total reserva', valor: total),
        const SizedBox(height: 8),
        _Fila(
          etiqueta: 'Pagado',
          valor: pagado,
          color: ColoresApp.statusSuccess,
        ),
        const SizedBox(height: 8),
        _Fila(
          etiqueta: 'Saldo pendiente',
          valor: _saldo,
          color: _saldo > 0 ? ColoresApp.statusDanger : ColoresApp.textMuted,
        ),
        const SizedBox(height: 14),
        BarraProgreso(
          progreso: _progreso,
          alto: 6,
          color: pagada ? ColoresApp.statusSuccess : ColoresApp.statusWarning,
        ),
        const SizedBox(height: 6),
        Text(
          '$porcentaje % pagado',
          style: TipografiaApp.caption.copyWith(fontSize: 11.5),
        ),
        const SizedBox(height: 14),
        const Divider(height: 1, color: ColoresApp.borderFila),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text('Total', style: TipografiaApp.cuerpoMedium),
            ),
            Text(
              formatearPrecio(total),
              style: TipografiaApp.heading3.copyWith(
                color: ColoresApp.statusInfo,
              ),
            ),
          ],
        ),
        if (alCancelar != null) ...[
          const SizedBox(height: 16),
          BotonDestructivo(
            etiqueta: 'Cancelar reserva',
            icono: Icons.cancel_outlined,
            expandido: true,
            suave: true,
            alPresionar: alCancelar,
          ),
        ],
      ],
    );
  }
}

/// Etiqueta a la izquierda, importe a la derecha.
class _Fila extends StatelessWidget {
  const _Fila({required this.etiqueta, required this.valor, this.color});

  final String etiqueta;
  final int valor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            etiqueta,
            style: TipografiaApp.caption.copyWith(fontSize: 12.5),
          ),
        ),
        Text(
          formatearPrecio(valor),
          style: TipografiaApp.cuerpoMedium.copyWith(
            fontSize: 13,
            color: color ?? ColoresApp.textPrimary,
          ),
        ),
      ],
    );
  }
}
