import 'package:flutter/material.dart';

import '../../../../../core/formato.dart';
import '../../../../share/share.dart';

/// El estado de cuentas de una deuda y las dos acciones que la cierran.
///
/// Mismo bloque que el pie de una reserva —total, lo entregado, lo que falta y
/// la barra— porque es la misma pregunta; lo que cambia son los colores y las
/// acciones, y por eso cada módulo arma el suyo con los renglones compartidos
/// en vez de heredar un pie que tenga que saber de los dos.
///
/// **El saldo va en rojo, no en ámbar.** Es la diferencia con una reserva: un
/// apartado a medio pagar está en su estado normal, una deuda a medio cobrar
/// es plata en la calle. La barra sigue el mismo criterio: verde si va al día,
/// roja si el plazo se cumplió.
///
/// «Dar por perdida» está separada de todo lo demás y en rojo suave: no cobra
/// ni corrige nada, solo reconoce que esa plata no vuelve. Sacarla de la
/// cartera es su único efecto, y por eso conviene que cueste un clic aparte.
///
/// Parámetros:
/// - [total]: lo que se debe en total.
/// - [pagado]: lo entregado hasta ahora.
/// - [colorAvance]: el de la barra, decidido por la situación de la deuda.
/// - [alDarPorPerdida]: `null` si la deuda ya está cerrada.
/// - [alReabrir]: `null` salvo que esté dada por perdida. Deshace lo anterior.
///
/// Ejemplo:
/// ```dart
/// PieDeuda(
///   total: estado.montoTotal,
///   pagado: estado.montoPagado,
///   colorAvance: colorDeAvance(situacion),
///   alDarPorPerdida: editable ? _darPorPerdida : null,
/// )
/// ```
class PieDeuda extends StatelessWidget {
  const PieDeuda({
    super.key,
    required this.total,
    required this.pagado,
    required this.colorAvance,
    this.alDarPorPerdida,
    this.alReabrir,
  });

  final int total;
  final int pagado;
  final Color colorAvance;
  final VoidCallback? alDarPorPerdida;
  final VoidCallback? alReabrir;

  int get _saldo => (total - pagado).clamp(0, total);

  double get _progreso => total > 0 ? (pagado / total).clamp(0.0, 1.0) : 0.0;

  @override
  Widget build(BuildContext context) {
    final saldada = total > 0 && pagado >= total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        RenglonCuenta(
          etiqueta: 'Deuda total',
          valor: formatearPrecio(total),
        ),
        const SizedBox(height: 8),
        RenglonCuenta(
          etiqueta: 'Cobrado',
          valor: formatearPrecio(pagado),
          color: ColoresApp.statusSuccess,
        ),
        const SizedBox(height: 8),
        RenglonCuenta(
          etiqueta: 'Saldo por cobrar',
          valor: formatearPrecio(_saldo),
          color:
              _saldo > 0 ? ColoresApp.statusDanger : ColoresApp.textMuted,
        ),
        const SizedBox(height: 14),
        BarraProgreso(progreso: _progreso, alto: 6, color: colorAvance),
        const SizedBox(height: 8),
        Text(
          saldada
              ? 'Cobrada del todo'
              : '${(_progreso * 100).round()} % cobrado',
          style: TipografiaApp.caption.copyWith(fontSize: 11.5),
        ),
        if (alDarPorPerdida != null) ...[
          const SizedBox(height: 16),
          BotonDestructivo(
            etiqueta: 'Dar por perdida',
            icono: Icons.money_off_rounded,
            expandido: true,
            suave: true,
            alPresionar: alDarPorPerdida,
          ),
        ],
        if (alReabrir != null) ...[
          const SizedBox(height: 16),
          BotonSecundario(
            etiqueta: 'Volver a cobrarla',
            icono: Icons.undo_rounded,
            expandido: true,
            alPresionar: alReabrir,
          ),
        ],
      ],
    );
  }
}
