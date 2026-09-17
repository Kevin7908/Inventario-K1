import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/resultado.dart';
import '../../../../share/share.dart';
import '../modelo/compra_editor_state.dart';
import '../provider/compra_editor_provider.dart';
import '../widgets/panel_catalogo_compra.dart';
import '../widgets/panel_compra.dart';

/// Ficha de una remisión: dos paneles, como el punto de venta.
///
/// A la izquierda, el catálogo del que salen las líneas; a la derecha, la
/// remisión que se está armando con su total.
///
/// **No hay botón de guardar.** Se anota lo que llegó, se teclea su costo y la
/// ficha lo escribe sola, igual que el editor de órdenes: cada línea mete su
/// mercancía al inventario en el momento, que es como se recibe de verdad —la
/// caja se va vaciando y cada producto se cuenta cuando sale de ella—.
///
/// La compra **ya existe** cuando se llega aquí: `proveedor_id` es `NOT NULL`
/// y el número sale del consecutivo, así que quien abre la ficha la creó antes
/// con `DialogoNuevaCompra`.
class CompraDetalleVista extends ConsumerStatefulWidget {
  const CompraDetalleVista({
    super.key,
    required this.compraId,
    required this.alCerrar,
  });

  final int compraId;
  final VoidCallback alCerrar;

  @override
  ConsumerState<CompraDetalleVista> createState() => _CompraDetalleVistaState();
}

class _CompraDetalleVistaState extends ConsumerState<CompraDetalleVista> {
  final _focoBusqueda = FocusNode();

  @override
  void dispose() {
    _focoBusqueda.dispose();
    super.dispose();
  }

  /// Fuerza la escritura sin esperar el retardo. Lo usan `Ctrl+Enter` y el
  /// cierre de la ficha: si no, el último cambio se perdería con el `Timer`.
  Future<void> _guardarAhora() async {
    final resultado = await ref
        .read(compraEditorProvider(widget.compraId).notifier)
        .guardarAhora();
    if (!mounted) return;
    if (resultado case Fallo(:final mensaje)) {
      MensajeApp.error(context, mensaje);
    }
  }

  /// Sale al listado, y **descarta la remisión en la que no se anotó nada**.
  ///
  /// Abrir el cuadro y arrepentirse no puede dejar un borrador vacío en el
  /// listado: no explica ningún movimiento y no llegó a ser un documento. El
  /// que sí tiene líneas se queda como borrador, igual que una orden abierta.
  Future<void> _cerrar() async {
    final notifier = ref.read(compraEditorProvider(widget.compraId).notifier);

    final resultado = await notifier.guardarAhora();
    if (!mounted) return;
    if (resultado case Fallo(:final mensaje)) {
      MensajeApp.error(context, 'No se guardó el último cambio: $mensaje');
    }

    final estado = ref.read(compraEditorProvider(widget.compraId)).value;
    if (estado != null && estado.editable && estado.vacia) {
      await notifier.descartarVacia();
    }
    if (!mounted) return;

    widget.alCerrar();
  }

  @override
  Widget build(BuildContext context) {
    final provider = compraEditorProvider(widget.compraId);
    final cargando = ref.watch(provider.select((s) => !s.hasValue));

    if (cargando) {
      final error = ref.watch(provider.select((s) => s.error));
      if (error != null) {
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BotonVolver(etiqueta: 'Compras', alPresionar: widget.alCerrar),
              const SizedBox(height: 24),
              Expanded(
                child: EstadoVacio(
                  icono: Icons.error_outline_rounded,
                  titulo: 'No se pudo abrir la compra',
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
            _BarraSuperior(compraId: widget.compraId, alVolver: _cerrar),
            const Divider(color: ColoresApp.border, height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: PanelCatalogoCompra(
                      compraId: widget.compraId,
                      focoBusqueda: _focoBusqueda,
                    ),
                  ),
                  PanelCompra(compraId: widget.compraId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vuelta al listado, número de la remisión y estado del guardado.
///
/// No hay botón de guardar: la compra se persiste sola. Lo que sí hace falta
/// es decir en qué punto va, porque sin botón el usuario no tiene otra forma
/// de saber si su trabajo ya está a salvo —y aquí «a salvo» incluye el stock
/// que se acaba de recibir—.
class _BarraSuperior extends ConsumerWidget {
  const _BarraSuperior({required this.compraId, required this.alVolver});

  final int compraId;
  final VoidCallback alVolver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(
      compraEditorProvider(compraId).select((s) => (
            numero: s.value?.numero ?? '',
            guardado: s.value?.guardado ?? EstadoGuardadoCompra.guardado,
            motivo: s.value?.motivoBloqueo,
          )),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 16),
      child: Row(
        children: [
          BotonVolver(etiqueta: 'Compras', alPresionar: alVolver),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              datos.numero.isEmpty ? 'Compra' : datos.numero,
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

  final EstadoGuardadoCompra estado;
  final String? motivo;

  @override
  Widget build(BuildContext context) {
    final (icono, texto, color) = switch (estado) {
      EstadoGuardadoCompra.pendiente => (
          Icons.sync_rounded,
          'Sin guardar…',
          ColoresApp.textMuted,
        ),
      EstadoGuardadoCompra.guardando => (
          Icons.sync_rounded,
          'Guardando…',
          ColoresApp.textSecondary,
        ),
      EstadoGuardadoCompra.guardado => (
          Icons.cloud_done_outlined,
          'Guardada',
          ColoresApp.statusSuccess,
        ),
      EstadoGuardadoCompra.bloqueado => (
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
