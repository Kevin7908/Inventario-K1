import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/resultado.dart';
import '../../../../share2/share2.dart';
import '../modelo/reserva_editor_state.dart';
import '../provider/reserva_editor_provider.dart';
import '../widgets/panel_catalogo_reserva.dart';
import '../widgets/panel_reserva.dart';

/// Editor de una reserva: dos paneles, como el punto de venta.
///
/// A la izquierda, de dónde sale lo que se aparta y dónde se cobra; a la
/// derecha, la reserva que se está armando con su estado de cuentas.
///
/// La reserva **ya existe** cuando se llega aquí: `cliente_id` es `NOT NULL`,
/// así que quien abre el editor la creó antes con `DialogoNuevaReserva`. Eso
/// también evita reservas huérfanas —entrar y arrepentirse no quema un
/// consecutivo—.
class ReservaDetalleVista extends ConsumerStatefulWidget {
  const ReservaDetalleVista({
    super.key,
    required this.reservaId,
    required this.alCerrar,
  });

  final int reservaId;
  final VoidCallback alCerrar;

  @override
  ConsumerState<ReservaDetalleVista> createState() =>
      _ReservaDetalleVistaState();
}

class _ReservaDetalleVistaState extends ConsumerState<ReservaDetalleVista> {
  final _focoBusqueda = FocusNode();

  @override
  void dispose() {
    _focoBusqueda.dispose();
    super.dispose();
  }

  void _avisar(String mensaje, {bool esError = false}) => esError
      ? MensajeApp.error(context, mensaje)
      : MensajeApp.exito(context, mensaje);

  /// Fuerza la escritura sin esperar el retardo. Lo usan `Ctrl+Enter` y el
  /// cierre del editor: si no, el último cambio se perdería con el `Timer`.
  Future<void> _guardarAhora() async {
    final resultado = await ref
        .read(reservaEditorProvider(widget.reservaId).notifier)
        .guardarAhora();
    if (!mounted) return;
    if (resultado case Fallo(:final mensaje)) _avisar(mensaje, esError: true);
  }

  Future<void> _cerrar() async {
    final resultado = await ref
        .read(reservaEditorProvider(widget.reservaId).notifier)
        .guardarAhora();
    if (!mounted) return;
    if (resultado case Fallo(:final mensaje)) {
      _avisar('No se guardó el último cambio: $mensaje', esError: true);
    }
    widget.alCerrar();
  }

  @override
  Widget build(BuildContext context) {
    final provider = reservaEditorProvider(widget.reservaId);
    final cargando = ref.watch(provider.select((s) => !s.hasValue));
    if (cargando) {
      return const Center(
        child: CircularProgressIndicator(color: ColoresApp.goGreen),
      );
    }

    return AtajosFormulario(
      alGuardar: _guardarAhora,
      alCancelar: _cerrar,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
              _focoBusqueda.requestFocus(),
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BarraSuperior(reservaId: widget.reservaId, alVolver: _cerrar),
            const Divider(color: ColoresApp.border, height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: PanelCatalogoReserva(
                      reservaId: widget.reservaId,
                      focoBusqueda: _focoBusqueda,
                    ),
                  ),
                  PanelReserva(reservaId: widget.reservaId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vuelta al listado, número de la reserva y estado del guardado.
///
/// No hay botón de guardar: la reserva se persiste sola. Lo que sí hace falta
/// es decir en qué punto va, porque sin botón el usuario no tiene otra forma
/// de saber si su trabajo ya está a salvo.
class _BarraSuperior extends ConsumerWidget {
  const _BarraSuperior({required this.reservaId, required this.alVolver});

  final int reservaId;
  final VoidCallback alVolver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(
      reservaEditorProvider(reservaId).select((s) => (
            numero: s.value?.numero ?? '',
            guardado: s.value?.guardado ?? EstadoGuardadoReserva.guardado,
            motivo: s.value?.motivoBloqueo,
          )),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 16),
      child: Row(
        children: [
          BotonVolver(etiqueta: 'Reservas', alPresionar: alVolver),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              datos.numero.isEmpty ? 'Reserva' : datos.numero,
              style: TipografiaApp.heading3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _EstadoGuardado(estado: datos.guardado, motivo: datos.motivo),
        ],
      ),
    );
  }
}

/// En qué punto va el guardado automático, en una línea.
class _EstadoGuardado extends StatelessWidget {
  const _EstadoGuardado({required this.estado, required this.motivo});

  final EstadoGuardadoReserva estado;
  final String? motivo;

  @override
  Widget build(BuildContext context) {
    final (icono, texto, color) = switch (estado) {
      EstadoGuardadoReserva.pendiente => (
          Icons.sync_rounded,
          'Sin guardar…',
          ColoresApp.textMuted,
        ),
      EstadoGuardadoReserva.guardando => (
          Icons.sync_rounded,
          'Guardando…',
          ColoresApp.textSecondary,
        ),
      EstadoGuardadoReserva.guardado => (
          Icons.cloud_done_outlined,
          'Guardada',
          ColoresApp.statusSuccess,
        ),
      EstadoGuardadoReserva.bloqueado => (
          Icons.error_outline_rounded,
          motivo ?? 'No se pudo guardar',
          ColoresApp.statusDanger,
        ),
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 17, color: color),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              texto,
              style: TipografiaApp.caption.copyWith(color: color),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
