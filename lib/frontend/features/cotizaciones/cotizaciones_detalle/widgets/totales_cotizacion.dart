import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/formato.dart';
import '../../../../../core/iva_app.dart';
import '../../../../share/share.dart';
import '../provider/cotizacion_editor_provider.dart';

/// Pie de la cotización: subtotal, descuento, IVA y total.
///
/// Lo pinta [PieTotales] de share, que es el mismo pie del punto de venta y
/// del editor de órdenes. Aquí solo queda de dónde salen los números.
///
/// El subtotal se pinta **solo si hay descuento**: sin él sería un número
/// repetido del total.
///
/// Es `Stateful` por el `TextEditingController`. No se resincroniza en cada
/// tecla a propósito —movería el cursor—; sí cuando el recorte al subtotal, que
/// hace el estado en Dart, cambió el valor de verdad al quitar una línea.
class TotalesCotizacion extends ConsumerStatefulWidget {
  const TotalesCotizacion({super.key, required this.cotizacionId});

  final int? cotizacionId;

  @override
  ConsumerState<TotalesCotizacion> createState() => _TotalesCotizacionState();
}

class _TotalesCotizacionState extends ConsumerState<TotalesCotizacion> {
  final _controlador = TextEditingController();
  final _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    final actual = ref
            .read(cotizacionEditorProvider(widget.cotizacionId))
            .value
            ?.descuento ??
        0;
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
      cotizacionEditorProvider(widget.cotizacionId).select((s) => (
            subtotal: s.value?.subtotal ?? 0,
            descuento: s.value?.descuento ?? 0,
            iva: s.value?.iva ?? 0,
            total: s.value?.total ?? 0,
          )),
    );

    final enTexto = int.tryParse(_controlador.text) ?? 0;
    if (enTexto != totales.descuento && !_foco.hasFocus) {
      _controlador.text = totales.descuento == 0 ? '' : '${totales.descuento}';
    }

    final hayDescuento = totales.descuento > 0;

    return PieTotales(
      subtotal: hayDescuento ? formatearPrecio(totales.subtotal) : null,
      total: formatearPrecio(totales.total),
      iva: hayIva ? formatearPrecio(totales.iva) : null,
      etiquetaIva: etiquetaIva,
      controladorDescuento: _controlador,
      focoDescuento: _foco,
      hayDescuento: hayDescuento,
      alCambiarDescuento: (texto) => ref
          .read(cotizacionEditorProvider(widget.cotizacionId).notifier)
          .cambiarDescuento(int.tryParse(texto) ?? 0),
    );
  }
}
