import 'package:flutter/material.dart';

import '../../../../backend/features/reservas/enum/enum_reserva.dart';
import '../../../../backend/features/reservas/modelo/reserva_resumen.dart';
import '../../../../core/formato.dart';
import '../../../share/share.dart';
import 'estado_reserva_ui.dart';

/// La tarjeta de una reserva en la rejilla, como en el diseño: quién apartó,
/// cuánto lleva pagado y cuánto falta.
///
/// Se monta sobre [TarjetaCatalogo] —marcador, título, subtítulo, acciones y
/// pie— en vez de dibujar otra tarjeta desde cero. Lo propio de reservas es el
/// pie: la barra de avance y las tres cifras.
///
/// **Las tres cifras van juntas a propósito.** «Abonado» solo dice algo al
/// lado de «Saldo»: $200.000 abonados es mucho o poco según lo que falte, y
/// esa es la pregunta que se hace quien atiende el mostrador.
class TarjetaReserva extends StatelessWidget {
  const TarjetaReserva({
    super.key,
    required this.reserva,
    required this.alPresionar,
  });

  final ReservaResumen reserva;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    // El estado del ciclo de vida solo se muestra cuando dice algo que el
    // saldo no: una reserva activa ya se explica con «Pagada»/«Abonando».
    final cerrada = reserva.estado != EstadoReserva.activa;

    return TarjetaCatalogo(
      titulo: reserva.nombreCliente,
      subtitulo: reserva.numero,
      alPresionar: alPresionar,
      marcador: MarcadorIdentidad(
        inicial: inicialDe(reserva.nombreCliente),
        colorFondo: ColoresApp.goGreen,
        colorFondoFin: ColoresApp.castletonGreen,
        lado: 44,
        radio: 12,
      ),
      acciones: cerrada
          ? BadgeEstadoReserva(estado: reserva.estado)
          : BadgeSaldoReserva(reserva: reserva),
      pie: _PieTarjeta(reserva: reserva),
    );
  }
}

class _PieTarjeta extends StatelessWidget {
  const _PieTarjeta({required this.reserva});

  final ReservaResumen reserva;

  @override
  Widget build(BuildContext context) {
    final colorBarra = coloresDeSaldo(pagada: reserva.pagada).color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (reserva.fechaLimite != null) ...[
          Text(
            reserva.estaVencida
                ? 'Venció el ${formatearFecha(reserva.fechaLimite!)}'
                : 'Se guarda hasta el ${formatearFecha(reserva.fechaLimite!)}',
            style: TipografiaApp.caption.copyWith(
              fontSize: 12.5,
              color: reserva.estaVencida
                  ? ColoresApp.statusDanger
                  : ColoresApp.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
        ],
        BarraProgreso(progreso: reserva.porcentajePagado, color: colorBarra),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _Cifra(
                etiqueta: 'Abonado',
                valor: reserva.pagadoAcumulado,
                color: ColoresApp.statusSuccess,
              ),
            ),
            Expanded(
              child: _Cifra(
                etiqueta: 'Saldo',
                valor: reserva.saldo,
                color: ColoresApp.statusWarning,
                alineacion: TextAlign.center,
              ),
            ),
            Expanded(
              child: _Cifra(
                etiqueta: 'Total',
                valor: reserva.totalReserva,
                color: ColoresApp.textPrimary,
                alineacion: TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Etiqueta tenue arriba y el importe debajo, como las tres del diseño.
class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.etiqueta,
    required this.valor,
    required this.color,
    this.alineacion = TextAlign.left,
  });

  final String etiqueta;
  final int valor;
  final Color color;
  final TextAlign alineacion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: switch (alineacion) {
        TextAlign.center => CrossAxisAlignment.center,
        TextAlign.right => CrossAxisAlignment.end,
        _ => CrossAxisAlignment.start,
      },
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          etiqueta,
          style: TipografiaApp.caption.copyWith(fontSize: 11),
          textAlign: alineacion,
        ),
        const SizedBox(height: 2),
        Text(
          formatearPrecio(valor),
          style: TipografiaApp.cuerpoMedium.copyWith(
            fontSize: 13.5,
            color: color,
          ),
          textAlign: alineacion,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
