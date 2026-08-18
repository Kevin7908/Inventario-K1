import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/resultado.dart';
import '../../../share2/share2.dart';
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

  Future<void> _cobrar() async {
    final total = ref.read(posProvider).total;
    final metodoPago = await DialogoCobro.mostrar(context, total: total);
    if (metodoPago == null || !mounted) return;

    final resultado =
        await ref.read(posProvider.notifier).cobrar(metodoPago: metodoPago);
    if (!mounted) return;

    switch (resultado) {
      case Exito():
        _avisar('Venta cobrada. La factura quedó registrada.');
      case Fallo(:final mensaje):
        _avisar(mensaje, esError: true);
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
