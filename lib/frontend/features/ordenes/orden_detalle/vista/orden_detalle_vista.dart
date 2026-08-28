import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/resultado.dart';
import '../../../../share/share.dart';
import '../modelo/orden_editor_state.dart';
import '../provider/orden_editor_provider.dart';
import '../widgets/panel_catalogo_orden.dart';
import '../widgets/panel_orden.dart';

/// Editor de una orden de servicio: dos paneles, como el punto de venta.
///
/// A la izquierda, de dónde salen las líneas —repuestos, servicios o cargos
/// sueltos—; a la derecha, la orden que se está armando.
///
/// La orden **ya existe** cuando se llega aquí: `moto_id` y `cliente_id` son
/// `NOT NULL`, así que quien abre el editor la creó antes con
/// `DialogoNuevaOrden`. Eso también evita órdenes huérfanas —entrar y
/// arrepentirse no quema un consecutivo.
class OrdenDetalleVista extends ConsumerStatefulWidget {
  const OrdenDetalleVista({
    super.key,
    required this.ordenId,
    required this.alCerrar,
  });

  final int ordenId;
  final VoidCallback alCerrar;

  @override
  ConsumerState<OrdenDetalleVista> createState() => _OrdenDetalleVistaState();
}

class _OrdenDetalleVistaState extends ConsumerState<OrdenDetalleVista> {
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
  /// cierre del editor: si no, el último cambio se perdería con el `Timer`
  /// pendiente.
  Future<void> _guardarAhora() async {
    final resultado =
        await ref.read(ordenEditorProvider(widget.ordenId).notifier)
            .guardarAhora();
    if (!mounted) return;
    if (resultado case Fallo(:final mensaje)) _avisar(mensaje, esError: true);
  }

  Future<void> _cerrar() async {
    final resultado =
        await ref.read(ordenEditorProvider(widget.ordenId).notifier)
            .guardarAhora();
    if (!mounted) return;
    if (resultado case Fallo(:final mensaje)) {
      _avisar('No se guardó el último cambio: $mensaje', esError: true);
    }
    widget.alCerrar();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ordenEditorProvider(widget.ordenId);
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
            _BarraSuperior(ordenId: widget.ordenId, alVolver: _cerrar),
            const Divider(color: ColoresApp.border, height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: PanelCatalogoOrden(
                      ordenId: widget.ordenId,
                      focoBusqueda: _focoBusqueda,
                    ),
                  ),
                  PanelOrden(
                    ordenId: widget.ordenId,
                    alImprimir: () =>
                        _avisar('Próximamente: vista previa en PDF.'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vuelta al listado, número de la orden y estado del guardado.
///
/// No hay botón de guardar: la orden se persiste sola. Lo que sí hace falta es
/// decir en qué punto va, porque sin botón el usuario no tiene otra forma de
/// saber si su trabajo ya está a salvo.
class _BarraSuperior extends ConsumerWidget {
  const _BarraSuperior({required this.ordenId, required this.alVolver});

  final int ordenId;
  final VoidCallback alVolver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(
      ordenEditorProvider(ordenId).select((s) => (
            numero: s.value?.numero ?? '',
            guardado: s.value?.guardado ?? EstadoGuardadoOrden.guardado,
            motivo: s.value?.motivoBloqueo,
          )),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 16),
      child: Row(
        children: [
          BotonVolver(etiqueta: 'Órdenes', alPresionar: alVolver),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              datos.numero.isEmpty ? 'Orden' : datos.numero,
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

  final EstadoGuardadoOrden estado;
  final String? motivo;

  @override
  Widget build(BuildContext context) {
    final (icono, texto, color) = switch (estado) {
      EstadoGuardadoOrden.pendiente => (
          Icons.sync_rounded,
          'Sin guardar…',
          ColoresApp.textMuted,
        ),
      EstadoGuardadoOrden.guardando => (
          Icons.sync_rounded,
          'Guardando…',
          ColoresApp.textSecondary,
        ),
      EstadoGuardadoOrden.guardado => (
          Icons.cloud_done_outlined,
          'Guardada',
          ColoresApp.statusSuccess,
        ),
      EstadoGuardadoOrden.bloqueado => (
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
