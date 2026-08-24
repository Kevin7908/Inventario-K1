import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/resultado.dart';
import '../../../../share2/share2.dart';
import '../modelo/deuda_editor_state.dart';
import '../provider/deuda_editor_provider.dart';
import '../widgets/panel_catalogo_deuda.dart';
import '../widgets/panel_deuda.dart';

/// Ficha de una deuda: dos paneles, como el punto de venta.
///
/// A la izquierda, de dónde salen los repuestos que se fían y dónde se cobra;
/// a la derecha, la deuda que se está armando con su estado de cuentas.
///
/// Es la misma pantalla que el editor de reservas **porque el gesto es el
/// mismo** —elegir mercancía del catálogo y cobrar—, con una diferencia que
/// vale por todo el módulo: apartar deja el repuesto en la bodega y fiar lo
/// saca montado en una moto. Por eso una reserva cancelada devuelve su
/// mercancía al inventario y una deuda dada por perdida no.
///
/// La deuda **ya existe** cuando se llega aquí: `cliente_id` es `NOT NULL`,
/// así que quien abre la ficha la creó antes con `DialogoNuevaDeuda`. Eso
/// también evita deudas huérfanas —entrar y arrepentirse no quema un
/// consecutivo—.
class DeudaDetalleVista extends ConsumerStatefulWidget {
  const DeudaDetalleVista({
    super.key,
    required this.deudaId,
    required this.alCerrar,
  });

  final int deudaId;
  final VoidCallback alCerrar;

  @override
  ConsumerState<DeudaDetalleVista> createState() => _DeudaDetalleVistaState();
}

class _DeudaDetalleVistaState extends ConsumerState<DeudaDetalleVista> {
  final _focoBusqueda = FocusNode();

  @override
  void dispose() {
    _focoBusqueda.dispose();
    super.dispose();
  }

  void _avisar(String mensaje) => MensajeApp.error(context, mensaje);

  /// Fuerza la escritura sin esperar el retardo. Lo usan `Ctrl+Enter` y el
  /// cierre de la ficha: si no, el último cambio se perdería con el `Timer`.
  Future<void> _guardarAhora() async {
    final resultado = await ref
        .read(deudaEditorProvider(widget.deudaId).notifier)
        .guardarAhora();
    if (!mounted) return;
    if (resultado case Fallo(:final mensaje)) _avisar(mensaje);
  }

  Future<void> _cerrar() async {
    final resultado = await ref
        .read(deudaEditorProvider(widget.deudaId).notifier)
        .guardarAhora();
    if (!mounted) return;
    if (resultado case Fallo(:final mensaje)) {
      _avisar('No se guardó el último cambio: $mensaje');
    }
    widget.alCerrar();
  }

  @override
  Widget build(BuildContext context) {
    final provider = deudaEditorProvider(widget.deudaId);
    final cargando = ref.watch(provider.select((s) => !s.hasValue));

    if (cargando) {
      final error = ref.watch(provider.select((s) => s.error));
      if (error != null) {
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BotonVolver(
                etiqueta: 'Cuentas por cobrar',
                alPresionar: widget.alCerrar,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: EstadoVacio(
                  icono: Icons.error_outline_rounded,
                  titulo: 'No se pudo abrir la deuda',
                  pista: '$error',
                ),
              ),
            ],
          ),
        );
      }
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
            _BarraSuperior(deudaId: widget.deudaId, alVolver: _cerrar),
            const Divider(color: ColoresApp.border, height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: PanelCatalogoDeuda(
                      deudaId: widget.deudaId,
                      focoBusqueda: _focoBusqueda,
                    ),
                  ),
                  PanelDeuda(deudaId: widget.deudaId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vuelta al listado, número de la deuda y estado del guardado.
///
/// No hay botón de guardar: la deuda se persiste sola. Lo que sí hace falta es
/// decir en qué punto va, porque sin botón el usuario no tiene otra forma de
/// saber si su trabajo ya está a salvo —y aquí «a salvo» incluye el stock que
/// se acaba de descontar—.
class _BarraSuperior extends ConsumerWidget {
  const _BarraSuperior({required this.deudaId, required this.alVolver});

  final int deudaId;
  final VoidCallback alVolver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(
      deudaEditorProvider(deudaId).select((s) => (
            numero: s.value?.numero ?? '',
            guardado: s.value?.guardado ?? EstadoGuardadoDeuda.guardado,
            motivo: s.value?.motivoBloqueo,
          )),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 16),
      child: Row(
        children: [
          BotonVolver(etiqueta: 'Cuentas por cobrar', alPresionar: alVolver),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              datos.numero.isEmpty ? 'Deuda' : datos.numero,
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

  final EstadoGuardadoDeuda estado;
  final String? motivo;

  @override
  Widget build(BuildContext context) {
    final (icono, texto, color) = switch (estado) {
      EstadoGuardadoDeuda.pendiente => (
          Icons.sync_rounded,
          'Sin guardar…',
          ColoresApp.textMuted,
        ),
      EstadoGuardadoDeuda.guardando => (
          Icons.sync_rounded,
          'Guardando…',
          ColoresApp.textSecondary,
        ),
      EstadoGuardadoDeuda.guardado => (
          Icons.cloud_done_outlined,
          'Guardada',
          ColoresApp.statusSuccess,
        ),
      EstadoGuardadoDeuda.bloqueado => (
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
