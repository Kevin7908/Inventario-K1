import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import '../../../../../core/resultado.dart';
import '../../../../share2/share2.dart';
import '../modelo/cotizacion_editor_state.dart';
import '../provider/cotizacion_editor_provider.dart';
import '../provider/cotizar_a_reserva_provider.dart';
import '../widgets/dialogo_reservar_cotizacion_widget.dart';
import '../widgets/panel_catalogo.dart';
import '../widgets/panel_cotizacion.dart';

/// Editor de cotización: dos paneles, como el punto de venta.
///
/// A la izquierda, de dónde salen las líneas —productos, servicios o líneas
/// libres—; a la derecha, la cotización que se está armando. [cotizacion] en
/// `null` abre una nueva.
class CotizacionDetalleVista extends ConsumerStatefulWidget {
  const CotizacionDetalleVista({
    super.key,
    this.cotizacion,
    required this.alCerrar,
  });

  final CotizacionResumen? cotizacion;
  final VoidCallback alCerrar;

  @override
  ConsumerState<CotizacionDetalleVista> createState() =>
      _CotizacionDetalleVistaState();
}

class _CotizacionDetalleVistaState
    extends ConsumerState<CotizacionDetalleVista> {
  final _focoBusqueda = FocusNode();

  int? get _id => widget.cotizacion?.id;

  @override
  void dispose() {
    _focoBusqueda.dispose();
    super.dispose();
  }

  void _avisar(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: TipografiaApp.sobrePrimario(TipografiaApp.cuerpo),
        ),
        backgroundColor:
            esError ? ColoresApp.statusDanger : ColoresApp.statusSuccess,
      ),
    );
  }

  /// Fuerza el guardado sin esperar el retardo. Lo usan `Ctrl+Enter` y el
  /// cierre del editor.
  Future<void> _guardarAhora() async {
    final resultado =
        await ref.read(cotizacionEditorProvider(_id).notifier).guardarAhora();
    if (!mounted) return;
    if (resultado case Fallo(:final mensaje)) _avisar(mensaje, esError: true);
  }

  /// Al salir se vacía el temporizador pendiente: si no, el último cambio se
  /// perdería junto con el provider. Si lo que queda no se puede guardar, se
  /// avisa en vez de cerrar en silencio.
  Future<void> _cerrar() async {
    final resultado =
        await ref.read(cotizacionEditorProvider(_id).notifier).guardarAhora();
    if (!mounted) return;
    if (resultado case Fallo(:final mensaje)) {
      _avisar('No se guardó el último cambio: $mensaje', esError: true);
    }
    widget.alCerrar();
  }

  /// Solo se reserva lo que tiene stock detrás, y solo de una cotización ya
  /// guardada: la reserva apunta a su id.
  Future<void> _reservar() async {
    final cotizacion = widget.cotizacion;
    final estado = ref.read(cotizacionEditorProvider(_id)).value;
    if (estado == null) return;

    if (cotizacion == null) {
      _avisar('Guarda la cotización antes de crear una reserva.', esError: true);
      return;
    }
    if (estado.cliente == null) {
      _avisar('Elige un cliente para poder reservar.', esError: true);
      return;
    }

    final items = CotizarAReservaUseCase.mapearItems(estado.items);
    if (items.isEmpty) {
      _avisar(
        'No hay nada reservable: solo los productos descuentan inventario.',
        esError: true,
      );
      return;
    }

    final creada = await DialogoReservarCotizacion.mostrar(
      context,
      cotizacion: cotizacion,
      items: items,
      totalReserva: estado.total,
    );
    if (!creada || !mounted) return;
    _avisar('Reserva creada. La encuentras en el módulo Reservas.');
    await _cerrar();
  }

  @override
  Widget build(BuildContext context) {
    final provider = cotizacionEditorProvider(_id);
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
            _BarraSuperior(cotizacionId: _id, alVolver: _cerrar),
            const Divider(color: ColoresApp.border, height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: PanelCatalogo(
                      cotizacionId: _id,
                      focoBusqueda: _focoBusqueda,
                    ),
                  ),
                  PanelCotizacion(
                    cotizacionId: _id,
                    alReservar: _reservar,
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

/// Vuelta al listado, número de la cotización y estado del guardado.
///
/// No hay botón de guardar: la cotización se persiste sola. Lo que sí hace
/// falta es decir en qué punto va, porque sin botón el usuario no tiene otra
/// forma de saber si su trabajo ya está a salvo.
class _BarraSuperior extends ConsumerWidget {
  const _BarraSuperior({required this.cotizacionId, required this.alVolver});

  final int? cotizacionId;
  final VoidCallback alVolver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(
      cotizacionEditorProvider(cotizacionId).select((s) => (
            numero: s.value?.numero ?? '',
            guardado: s.value?.guardado ?? EstadoGuardado.sinCambios,
            motivo: s.value?.motivoBloqueo,
          )),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 16),
      child: Row(
        children: [
          BotonVolver(etiqueta: 'Cotizaciones', alPresionar: alVolver),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              datos.numero.isEmpty ? 'Nueva cotización' : datos.numero,
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

  final EstadoGuardado estado;
  final String? motivo;

  @override
  Widget build(BuildContext context) {
    final (icono, texto, color) = switch (estado) {
      EstadoGuardado.sinCambios => (
          Icons.edit_note_rounded,
          'Se guarda sola',
          ColoresApp.textMuted,
        ),
      EstadoGuardado.pendiente => (
          Icons.sync_rounded,
          'Sin guardar…',
          ColoresApp.textMuted,
        ),
      EstadoGuardado.guardando => (
          Icons.sync_rounded,
          'Guardando…',
          ColoresApp.textSecondary,
        ),
      EstadoGuardado.guardado => (
          Icons.cloud_done_outlined,
          'Guardada',
          ColoresApp.statusSuccess,
        ),
      EstadoGuardado.bloqueado => (
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
