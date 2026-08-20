import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/formato.dart';
import '../../../../../core/iva_app.dart';
import '../../../../share2/share2.dart';
import '../provider/cotizacion_editor_provider.dart';

/// Pie de la cotización: subtotal, descuento, IVA y total.
///
/// El renglón de IVA va **debajo del total y no encima**, porque no suma: los
/// precios ya lo traen dentro (ver `iva_app.dart`), así que solo dice cuánto
/// del total es impuesto. Con `kIva` en 0 no se pinta: sería un `$0` que solo
/// estorba.
///
/// El subtotal **sí** se pinta siempre que haya descuento: sin él, la rebaja
/// saldría de la nada. Sin descuento sigue siendo un número repetido del total
/// y se esconde.
class TotalesCotizacion extends ConsumerWidget {
  const TotalesCotizacion({super.key, required this.cotizacionId});

  final int? cotizacionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totales = ref.watch(
      cotizacionEditorProvider(cotizacionId).select((s) => (
            subtotal: s.value?.subtotal ?? 0,
            descuento: s.value?.descuento ?? 0,
            iva: s.value?.iva ?? 0,
            total: s.value?.total ?? 0,
          )),
    );

    final hayDescuento = totales.descuento > 0;

    return Column(
      children: [
        if (hayDescuento) ...[
          _Renglon(etiqueta: 'Subtotal', valor: totales.subtotal),
          const SizedBox(height: 8),
        ],
        // El recorte al subtotal lo hace el estado, así que el campo no
        // necesita conocer el tope.
        _CampoDescuento(cotizacionId: cotizacionId),
        const SizedBox(height: 12),
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
        if (hayIva) ...[
          const SizedBox(height: 6),
          _Renglon(etiqueta: etiquetaIva, valor: totales.iva),
        ],
      ],
    );
  }
}

/// Renglón de descuento con su campo editable.
///
/// Es `Stateful` por el `TextEditingController`. No se resincroniza desde el
/// estado en cada cambio a propósito: el recorte al subtotal lo hace el
/// notifier, y reescribir el campo mientras se teclea movería el cursor. Lo
/// que sí se corrige es cuando el recorte cambió el valor de verdad —al quitar
/// una línea—, porque ahí el campo estaría mintiendo.
class _CampoDescuento extends ConsumerStatefulWidget {
  const _CampoDescuento({required this.cotizacionId});

  final int? cotizacionId;

  @override
  ConsumerState<_CampoDescuento> createState() => _CampoDescuentoState();
}

class _CampoDescuentoState extends ConsumerState<_CampoDescuento> {
  final _controlador = TextEditingController();
  final _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    final actual =
        ref.read(cotizacionEditorProvider(widget.cotizacionId)).value?.descuento ??
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
    final descuento = ref.watch(
      cotizacionEditorProvider(widget.cotizacionId)
          .select((s) => s.value?.descuento ?? 0),
    );

    // Solo se reescribe si el campo quedó desfasado del estado y no lo está
    // editando el usuario: es el caso de "quité una línea y la rebaja ya no
    // cabía".
    final enTexto = int.tryParse(_controlador.text) ?? 0;
    if (enTexto != descuento && !_foco.hasFocus) {
      _controlador.text = descuento == 0 ? '' : '$descuento';
    }

    final estilo = TipografiaApp.cuerpo.copyWith(
      fontSize: 13,
      color: descuento > 0 ? ColoresApp.statusWarning : ColoresApp.textSecondary,
    );

    return Row(
      children: [
        Text(
          'Descuento',
          style: TipografiaApp.cuerpo.copyWith(
            fontSize: 13,
            color: ColoresApp.textSecondary,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 110,
          height: 26,
          child: TextField(
            controller: _controlador,
            focusNode: _foco,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: estilo,
            onChanged: (texto) {
              final valor = int.tryParse(texto) ?? 0;
              ref
                  .read(cotizacionEditorProvider(widget.cotizacionId).notifier)
                  .cambiarDescuento(valor);
            },
            decoration: InputDecoration(
              isDense: true,
              prefixText: descuento > 0 ? r'-$' : r'$',
              prefixStyle: estilo,
              hintText: '0',
              hintStyle: TipografiaApp.deshabilitado(estilo),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              filled: true,
              fillColor: ColoresApp.bgCard,
              border: _borde(ColoresApp.borderInput),
              enabledBorder: _borde(ColoresApp.borderInput),
              focusedBorder: _borde(ColoresApp.borderFocus),
            ),
          ),
        ),
      ],
    );
  }

  static OutlineInputBorder _borde(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color),
      );
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
