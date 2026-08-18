import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/formato.dart';
import '../../../../../core/iva_app.dart';
import '../../../../share2/share2.dart';
import '../provider/cotizacion_editor_provider.dart';

/// Pie de la cotización: subtotal, IVA y total.
///
/// **Con `kIva` en 0 no se pinta el renglón de IVA ni el de subtotal**: serían
/// un `$0` y un número repetido que solo estorban. El taller no factura IVA
/// hoy; el día que `kIva` deje de ser 0, los dos renglones aparecen solos.
class TotalesCotizacion extends ConsumerWidget {
  const TotalesCotizacion({super.key, required this.cotizacionId});

  final int? cotizacionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totales = ref.watch(
      cotizacionEditorProvider(cotizacionId).select((s) => (
            subtotal: s.value?.subtotal ?? 0,
            iva: s.value?.iva ?? 0,
            total: s.value?.total ?? 0,
          )),
    );

    return Column(
      children: [
        if (hayIva) ...[
          _Renglon(etiqueta: 'Subtotal', valor: totales.subtotal),
          const SizedBox(height: 8),
          _Renglon(etiqueta: etiquetaIva, valor: totales.iva),
          const SizedBox(height: 12),
        ],
        // Línea punteada sobre el total, como en el diseño.
        const _SeparadorPunteado(),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total', style: TipografiaApp.heading3.copyWith(fontSize: 18)),
            Text(
              formatearPrecio(totales.total),
              style: TipografiaApp.heading3.copyWith(
                fontSize: 18,
                color: ColoresApp.castletonGreen,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// `border-top: 1px dashed #D7DCD8` del diseño. Flutter no tiene bordes
/// punteados, así que se pinta como una fila de guiones cortos.
class _SeparadorPunteado extends StatelessWidget {
  const _SeparadorPunteado();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        const anchoGuion = 4.0;
        const hueco = 3.0;
        final cuantos =
            (restricciones.maxWidth / (anchoGuion + hueco)).floor().clamp(1, 400);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            cuantos,
            (_) => const SizedBox(
              width: anchoGuion,
              height: 1,
              child: ColoredBox(color: ColoresApp.borderInput),
            ),
          ),
        );
      },
    );
  }
}

class _Renglon extends StatelessWidget {
  const _Renglon({required this.etiqueta, required this.valor});

  final String etiqueta;
  final int valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          etiqueta,
          style: TipografiaApp.cuerpo.copyWith(
            fontSize: 13,
            color: ColoresApp.textSecondary,
          ),
        ),
        Text(
          formatearPrecio(valor),
          style: TipografiaApp.cuerpo.copyWith(
            fontSize: 13,
            color: ColoresApp.textSecondary,
          ),
        ),
      ],
    );
  }
}
