import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/reservas/enum/enum_reserva.dart';
import '../../../../../core/formato.dart';
import '../../../../share2/share2.dart';
import '../provider/reserva_editor_provider.dart';

/// La cabecera de la reserva: de dónde salió, hasta cuándo se guarda y dónde
/// está su mercancía ahora mismo.
///
/// **Es solo de lectura.** Las dos acciones que cierran una reserva —entregar
/// y cancelar— viven juntas en el pie del panel derecho, bajo las cuentas, que
/// es donde se mira al terminar. Tenerlas también aquí obligaba a recordar en
/// cuál de los dos sitios estaba cada una.
class DialogoDatosReserva extends ConsumerStatefulWidget {
  const DialogoDatosReserva({super.key, required this.reservaId});

  final int reservaId;

  static Future<void> mostrar(
    BuildContext context, {
    required int reservaId,
  }) =>
      showDialog<void>(
        context: context,
        builder: (_) => DialogoDatosReserva(reservaId: reservaId),
      );

  @override
  ConsumerState<DialogoDatosReserva> createState() =>
      _DialogoDatosReservaState();
}

class _DialogoDatosReservaState extends ConsumerState<DialogoDatosReserva> {
  void _cerrar() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final datos = ref.watch(
      reservaEditorProvider(widget.reservaId).select((s) => (
            numero: s.value?.numero ?? '',
            estado: s.value?.estado ?? EstadoReserva.activa,
            limite: s.value?.fechaLimite,
            cotizacionId: s.value?.cotizacionId,
          )),
    );

    return AtajosFormulario(
      alGuardar: _cerrar,
      alCancelar: _cerrar,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 460,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ColoresApp.bgCard,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: ColoresApp.shadowMedium,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Datos de la reserva ${datos.numero}',
                style: TipografiaApp.heading3,
              ),
              const SizedBox(height: 16),
              FilaDato(
                icono: Icons.flag_outlined,
                texto: 'Estado: ${datos.estado.etiqueta}',
              ),
              const SizedBox(height: 8),
              FilaDato(
                icono: Icons.event_outlined,
                texto: datos.limite == null
                    ? 'Sin plazo: se guarda hasta nuevo aviso'
                    : 'Se guarda hasta el ${formatearFecha(datos.limite!)}',
              ),
              if (datos.cotizacionId != null) ...[
                const SizedBox(height: 8),
                const FilaDato(
                  icono: Icons.request_quote_outlined,
                  texto: 'Salió de una cotización. Cambiarla aquí no la '
                      'modifica: quedó congelada al reservar.',
                ),
              ],
              const SizedBox(height: 16),
              _AvisoInventario(estado: datos.estado),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Spacer(),
                  BotonSecundario(etiqueta: 'Listo', alPresionar: _cerrar),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dónde está la mercancía de esta reserva ahora mismo.
class _AvisoInventario extends StatelessWidget {
  const _AvisoInventario({required this.estado});

  final EstadoReserva estado;

  @override
  Widget build(BuildContext context) {
    final (texto, icono) = switch (estado) {
      EstadoReserva.activa => (
          'Lo apartado ya salió del inventario disponible, aunque siga en la '
              'bodega. Cancelar la reserva es lo único que lo devuelve.',
          Icons.inventory_outlined,
        ),
      EstadoReserva.completada => (
          'El cliente se llevó la mercancía. La reserva está cerrada.',
          Icons.check_circle_outline_rounded,
        ),
      EstadoReserva.cancelada => (
          'Se devolvió al inventario todo lo que esta reserva tenía apartado.',
          Icons.undo_rounded,
        ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 14, color: ColoresApp.textMuted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            texto,
            style: TipografiaApp.caption.copyWith(fontSize: 11.5),
          ),
        ),
      ],
    );
  }
}
