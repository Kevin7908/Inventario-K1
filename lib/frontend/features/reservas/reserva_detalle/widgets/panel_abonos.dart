import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/reservas/modelo/reserva_abono.dart';
import '../../../../../core/formato.dart';
import '../../../../share2/share2.dart';
import '../provider/reserva_editor_provider.dart';
import 'form_abono.dart';

/// La mitad de dinero del editor: contra qué se abona, el formulario y lo que
/// ya se recibió.
///
/// **El contexto va arriba y no es decoración.** Registrar un abono es el
/// único gesto de esta pantalla que mueve plata, y quien lo hace está mirando
/// a un cliente al otro lado del mostrador: antes de teclear un monto tiene
/// que poder confirmar de quién es la reserva, para qué moto y qué se le
/// apartó, sin volver al otro panel.
class PanelAbonos extends ConsumerWidget {
  const PanelAbonos({super.key, required this.reservaId});

  final int reservaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = reservaEditorProvider(reservaId);
    final datos = ref.watch(
      provider.select((s) => (
            cliente: s.value?.clienteNombre ?? '',
            moto: s.value?.motoDescripcion,
            placa: s.value?.motoPlaca,
            lineas: s.value?.lineas.length ?? 0,
            total: s.value?.totalReserva ?? 0,
            saldo: s.value?.saldo ?? 0,
            editable: s.value?.editable ?? false,
          )),
    );
    final notifier = ref.read(provider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        _Contexto(
          cliente: datos.cliente,
          moto: datos.moto,
          placa: datos.placa,
          lineas: datos.lineas,
          total: datos.total,
        ),
        const SizedBox(height: 16),
        FormAbono(
          saldo: datos.saldo,
          habilitado: datos.editable,
          alRegistrar: (monto, metodo, referencia) => unawaited(
            notifier.registrarAbono(
              monto: monto,
              metodoPago: metodo,
              referencia: referencia,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Historial(reservaId: reservaId),
      ],
    );
  }
}

/// A quién y para qué moto se le aparta, y cuánto suma.
class _Contexto extends StatelessWidget {
  const _Contexto({
    required this.cliente,
    required this.moto,
    required this.placa,
    required this.lineas,
    required this.total,
  });

  final String cliente;
  final String? moto;
  final String? placa;
  final int lineas;
  final int total;

  @override
  Widget build(BuildContext context) {
    final descripcionMoto = [?moto, ?placa].join(' · ');

    return PanelSeccion(
      titulo: 'Se le aparta a',
      icono: Icons.person_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FichaResumen(
            titulo: cliente.isEmpty ? 'Sin cliente' : cliente,
            subtitulo: descripcionMoto.isEmpty
                ? 'Sin moto asociada'
                : descripcionMoto,
            inicial: cliente.isEmpty ? null : inicialDe(cliente),
            icono: cliente.isEmpty ? Icons.person_outline : null,
          ),
          const SizedBox(height: 12),
          FilaDato(
            icono: Icons.inventory_2_outlined,
            texto: lineas == 1 ? '1 producto apartado' : '$lineas productos apartados',
          ),
          const SizedBox(height: 6),
          FilaDato(
            icono: Icons.sell_outlined,
            texto: 'Total de la reserva: ${formatearPrecio(total)}',
          ),
        ],
      ),
    );
  }
}

/// Lo que ya se recibió, de lo más reciente a lo más viejo.
class _Historial extends ConsumerWidget {
  const _Historial({required this.reservaId});

  final int reservaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abonos = ref.watch(
      reservaEditorProvider(reservaId)
          .select((s) => s.value?.abonos ?? const <ReservaAbono>[]),
    );

    return PanelSeccion(
      titulo: 'Movimientos',
      icono: Icons.receipt_long_outlined,
      child: abonos.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Todavía no se ha recibido nada.',
                style: TipografiaApp.caption,
              ),
            )
          : Column(
              children: [
                for (final abono in abonos) _FilaAbono(abono: abono),
              ],
            ),
    );
  }
}

/// Un movimiento de dinero. Los negativos son devoluciones: aparecen cuando se
/// quita mercancía de una reserva ya abonada y hay que regresar la diferencia.
class _FilaAbono extends StatelessWidget {
  const _FilaAbono({required this.abono});

  final ReservaAbono abono;

  @override
  Widget build(BuildContext context) {
    final devolucion = abono.monto < 0;
    final color =
        devolucion ? ColoresApp.statusDanger : ColoresApp.statusSuccess;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(
            devolucion
                ? Icons.undo_rounded
                : Icons.arrow_downward_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  devolucion ? 'Devolución' : abono.metodoPago.etiqueta,
                  style: TipografiaApp.cuerpoMedium.copyWith(fontSize: 12.5),
                ),
                const SizedBox(height: 1),
                Text(
                  [
                    formatearFecha(abono.fechaPago),
                    if (abono.referenciaPago != null) abono.referenciaPago!,
                  ].join(' · '),
                  style: TipografiaApp.caption.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatearPrecio(abono.monto),
            style: TipografiaApp.cuerpoMedium.copyWith(
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
