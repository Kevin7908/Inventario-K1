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
/// Los colores son los mismos que usa la tarjeta del listado —verde lo
/// entregado, ámbar lo que falta— para que la misma reserva no se lea de dos
/// maneras según la pantalla.
///
/// Parámetros:
/// Las dos acciones van aquí, bajo las cuentas, porque es donde se mira al
/// terminar: entregar arriba —es el cierre normal— y cancelar debajo. **Hacen
/// lo contrario con el inventario**: entregar no devuelve nada porque el
/// cliente se llevó la mercancía; cancelar la devuelve entera. Por eso la
/// segunda va en rojo suave y la primera en verde.
///
/// Parámetros:
/// - [total]: lo que vale la mercancía apartada.
/// - [pagado]: lo entregado hasta ahora.
/// - [alEntregar]: `null` si la reserva ya está cerrada.
/// - [alCancelar]: `null` si la reserva ya no se puede cancelar.
class PieReserva extends StatelessWidget {
  const PieReserva({
    super.key,
    required this.total,
    required this.pagado,
    this.alEntregar,
    this.alCancelar,
  });

  final int total;
  final int pagado;
  final VoidCallback? alEntregar;
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
        RenglonCuenta(
          etiqueta: 'Total reserva',
          valor: formatearPrecio(total),
        ),
        const SizedBox(height: 8),
        RenglonCuenta(
          etiqueta: 'Pagado',
          valor: formatearPrecio(pagado),
          color: ColoresApp.statusSuccess,
        ),
        const SizedBox(height: 8),
        RenglonCuenta(
          etiqueta: 'Saldo pendiente',
          valor: formatearPrecio(_saldo),
          // Ámbar y no rojo: deber plata de un apartado es el estado normal
          // de una reserva, no un error. Es el mismo color con que la tarjeta
          // del listado pinta el saldo.
          color: _saldo > 0 ? ColoresApp.statusWarning : ColoresApp.textMuted,
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
              // El verde oscuro de marca, igual que el total de `PieTotales`:
              // un importe cerrado se pinta igual en los cuatro documentos.
              style: TipografiaApp.heading3.copyWith(
                fontSize: 18,
                color: ColoresApp.castletonGreen,
              ),
            ),
          ],
        ),
        if (alEntregar != null) ...[
          const SizedBox(height: 16),
          BotonPrimario(
            etiqueta: 'Marcar entregada',
            icono: Icons.check_rounded,
            expandido: true,
            alPresionar: alEntregar,
          ),
        ],
        if (alCancelar != null) ...[
          SizedBox(height: alEntregar != null ? 10 : 16),
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
