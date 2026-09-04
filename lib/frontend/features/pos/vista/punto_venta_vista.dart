import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/resultado.dart';
import '../../../share/share.dart';
import '../../documentos/provider/documentos_providers.dart';
import '../../documentos/traductores/venta_a_documento.dart';
import '../../documentos/widgets/dialogo_vista_previa.dart';
import '../provider/pos_providers.dart';
import '../widgets/dialogo_cobro.dart';
import '../widgets/panel_catalogo_pos.dart';
import '../widgets/panel_venta.dart';

/// Punto de venta: el mostrador del taller, en dos paneles.
///
/// A la izquierda el catálogo —panel de categorías y rejilla de tarjetas—; a
/// la derecha la venta que se está armando. Es la misma planta del editor de
/// cotizaciones, con dos diferencias de fondo: aquí el stock **sí** limita lo
/// que se puede vender, y la venta se cierra cobrando, no guardándose sola.
class PuntoVentaVista extends ConsumerStatefulWidget {
  const PuntoVentaVista({super.key});

  @override
  ConsumerState<PuntoVentaVista> createState() => _PuntoVentaVistaState();
}

class _PuntoVentaVistaState extends ConsumerState<PuntoVentaVista> {
  final _focoBusqueda = FocusNode();

  @override
  void dispose() {
    _focoBusqueda.dispose();
    super.dispose();
  }

  void _avisar(String mensaje, {bool esError = false}) => esError
      ? MensajeApp.error(context, mensaje)
      : MensajeApp.exito(context, mensaje);

  Future<void> _cobrar() async {
    final total = ref.read(posProvider).total;
    final metodoPago = await DialogoCobro.mostrar(context, total: total);
    if (metodoPago == null || !mounted) return;

    final (:resultado, :ventaId) =
        await ref.read(posProvider.notifier).cobrar(metodoPago: metodoPago);
    if (!mounted) return;

    switch (resultado) {
      case Exito():
        _avisar('Venta cobrada. Quedó registrada en el historial.');
        if (ventaId != null) await _imprimir(ventaId);
      case Fallo(:final mensaje):
        _avisar(mensaje, esError: true);
    }
  }

  /// Levanta la factura recién emitida y abre la vista previa.
  ///
  /// Va **después** de avisar que la venta se cobró, y su fallo se reporta
  /// aparte: la plata ya entró y el stock ya salió, así que un problema al
  /// imprimir no puede parecer que la venta no se hizo. El historial siempre
  /// permite volver a imprimirla.
  Future<void> _imprimir(int ventaId) async {
    try {
      final venta =
          await ref.read(repositorioVentasProvider).obtenerDetalle(ventaId);
      final ajustes = await leerAjustesImpresion(
        ref.read(repositorioConfiguracionProvider),
      );
      if (!mounted) return;

      await DialogoVistaPrevia.mostrar(
        context,
        documento: documentoDeVenta(venta: venta, negocio: ajustes.negocio),
        formato: ajustes.formato,
      );
    } catch (e) {
      if (!mounted) return;
      _avisar('La venta quedó registrada, pero no se pudo abrir la factura: $e',
          esError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _focoBusqueda.requestFocus(),
      },
      child: ColoredBox(
        color: ColoresApp.bgApp,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: PanelCatalogoPos(focoBusqueda: _focoBusqueda)),
            PanelVenta(alCobrar: _cobrar),
          ],
        ),
      ),
    );
  }
}
