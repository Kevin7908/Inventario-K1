import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formato.dart';
import '../../../../core/iva_app.dart';
import '../../../share2/share2.dart';
import '../provider/pos_providers.dart';

/// Pie del carrito: subtotal, descuento, total e IVA incluido.
///
/// Lo pinta [PieTotales] de share2, que es el mismo pie de los editores de
/// cotizaciones y de órdenes. Aquí solo queda de dónde salen los números.
///
/// El subtotal se pinta **siempre**, con descuento o sin él: en el mostrador
/// el cliente está mirando la pantalla y ver de dónde sale el total es parte
/// del cobro.
///
/// Es `Stateful` por el `TextEditingController`: lo que llega de fuera —vaciar
/// el carrito, un cobro, o el recorte de un descuento mayor que el subtotal—
/// sí pisa el campo, pero solo cuando no se está escribiendo en él.
class TotalesVenta extends ConsumerStatefulWidget {
  const TotalesVenta({super.key});

  @override
  ConsumerState<TotalesVenta> createState() => _TotalesVentaState();
}

class _TotalesVentaState extends ConsumerState<TotalesVenta> {
  final _controlador = TextEditingController();
  final _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    final actual = ref.read(posProvider).descuento;
    if (actual > 0) _controlador.text = '$actual';
  }

  @override
  void dispose() {
    _controlador.dispose();
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totales = ref.watch(
      posProvider.select((s) => (
            subtotal: s.subtotal,
            iva: s.iva,
            descuento: s.descuento,
            total: s.total,
          )),
    );

    final enTexto = int.tryParse(_controlador.text) ?? 0;
    if (enTexto != totales.descuento && !_foco.hasFocus) {
      _controlador.text = totales.descuento == 0 ? '' : '${totales.descuento}';
    }

    return PieTotales(
      subtotal: formatearPrecio(totales.subtotal),
      total: formatearPrecio(totales.total),
      iva: hayIva ? formatearPrecio(totales.iva) : null,
      etiquetaIva: etiquetaIva,
      controladorDescuento: _controlador,
      focoDescuento: _foco,
      hayDescuento: totales.descuento > 0,
      alCambiarDescuento: (texto) => ref
          .read(posProvider.notifier)
          .cambiarDescuento(int.tryParse(texto) ?? 0),
    );
  }
}
