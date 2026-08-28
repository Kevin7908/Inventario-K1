import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/formato.dart';
import '../../../../../core/iva_app.dart';
import '../../../../share/share.dart';
import '../provider/orden_editor_provider.dart';

/// Pie de la orden: subtotal, descuento, IVA y total.
///
/// Lo pinta [PieTotales] de share, que es el mismo pie del punto de venta y
/// del editor de cotizaciones. Aquí solo queda de dónde salen los números y
/// cuándo se puede pisar el campo de descuento.
///
/// El subtotal se pinta **solo si hay descuento**: sin él sería un número
/// repetido del total.
///
/// Es `Stateful` por el `TextEditingController`. No se resincroniza desde el
/// estado en cada tecla a propósito: reescribir el campo mientras se escribe
/// movería el cursor. Lo que sí se corrige es cuando **el repositorio recortó
/// el valor** —al quitar una línea, la rebaja que ya no cabe baja sola—,
/// porque ahí el campo estaría mintiendo.
///
/// Ese recorte es la diferencia con cotizaciones: allá lo hace el estado en
/// Dart y se ve al instante; aquí lo hace el repositorio, porque el subtotal
/// de una orden es la suma de tres tablas y ningún `CHECK` puede consultarlas.
/// El valor correcto llega con la relectura que sigue a cada escritura.
class TotalesOrden extends ConsumerStatefulWidget {
  const TotalesOrden({super.key, required this.ordenId});

  final int ordenId;

  @override
  ConsumerState<TotalesOrden> createState() => _TotalesOrdenState();
}

class _TotalesOrdenState extends ConsumerState<TotalesOrden> {
  final _controlador = TextEditingController();
  final _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    final actual =
        ref.read(ordenEditorProvider(widget.ordenId)).value?.descuento ?? 0;
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
      ordenEditorProvider(widget.ordenId).select((s) => (
            subtotal: s.value?.subtotal ?? 0,
            descuento: s.value?.descuento ?? 0,
            iva: s.value?.iva ?? 0,
            total: s.value?.total ?? 0,
            editable: s.value?.editable ?? false,
          )),
    );

    // Solo se reescribe si el campo quedó desfasado del estado y no lo está
    // editando el usuario: es el caso de "quité una línea y la rebaja ya no
    // cabía".
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
      editable: totales.editable,
      alCambiarDescuento: (texto) => ref
          .read(ordenEditorProvider(widget.ordenId).notifier)
          .cambiarDescuento(int.tryParse(texto) ?? 0),
    );
  }
}
