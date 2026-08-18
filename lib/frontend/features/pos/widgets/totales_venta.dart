import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formato.dart';
import '../../../../core/iva_app.dart';
import '../../../share2/share2.dart';
import '../provider/pos_providers.dart';

/// Pie del carrito: subtotal, IVA, descuento y total.
///
/// El **descuento se escribe aquí mismo**, en el renglón donde se lee: es un
/// número que se negocia mirando el total, y mandarlo a un campo aparte del
/// formulario obligaba a saltar entre dos sitios para cuadrarlo. El renglón
/// vive siempre, aunque el descuento sea 0, porque si no habría que descubrir
/// dónde se pone.
///
/// **Con `kIva` en 0 no se pinta el renglón de IVA**: sería un `$0` que solo
/// estorba. El de subtotal sí se queda: con descuento, subtotal y total son
/// números distintos.
class TotalesVenta extends ConsumerWidget {
  const TotalesVenta({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totales = ref.watch(
      posProvider.select((s) => (
            subtotal: s.subtotal,
            iva: s.iva,
            descuento: s.descuento,
            total: s.total,
          )),
    );

    return Column(
      children: [
        _Renglon(etiqueta: 'Subtotal', valor: formatearPrecio(totales.subtotal)),
        const SizedBox(height: 8),
        if (hayIva) ...[
          _Renglon(etiqueta: etiquetaIva, valor: formatearPrecio(totales.iva)),
          const SizedBox(height: 8),
        ],
        _RenglonDescuento(descuento: totales.descuento),
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
      ],
    );
  }
}

/// El renglón de descuento, con su importe editable.
///
/// Es `Stateful` por el `TextEditingController`, como [ControlCantidad]: el
/// valor de verdad lo manda el estado del punto de venta, y si este recorta lo
/// tecleado —un descuento mayor que el subtotal— el campo se vuelve a
/// sincronizar solo al perder el foco.
class _RenglonDescuento extends ConsumerStatefulWidget {
  const _RenglonDescuento({required this.descuento});

  final int descuento;

  @override
  ConsumerState<_RenglonDescuento> createState() => _RenglonDescuentoState();
}

class _RenglonDescuentoState extends ConsumerState<_RenglonDescuento> {
  late final TextEditingController _controlador =
      TextEditingController(text: _texto(widget.descuento));
  final _foco = FocusNode();

  static String _texto(int valor) => valor == 0 ? '' : '$valor';

  @override
  void initState() {
    super.initState();
    _foco.addListener(_sincronizar);
  }

  @override
  void didUpdateWidget(_RenglonDescuento anterior) {
    super.didUpdateWidget(anterior);
    // Lo que llega de fuera (vaciar el carrito, un cobro) sí pisa el campo,
    // pero solo si no se está escribiendo en él.
    if (!_foco.hasFocus && widget.descuento != anterior.descuento) {
      _controlador.text = _texto(widget.descuento);
    }
  }

  void _sincronizar() {
    if (!_foco.hasFocus) _controlador.text = _texto(widget.descuento);
  }

  @override
  void dispose() {
    _foco
      ..removeListener(_sincronizar)
      ..dispose();
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estilo = TipografiaApp.cuerpo.copyWith(
      fontSize: 13,
      color: ColoresApp.textSecondary,
    );

    return Row(
      children: [
        Text('Descuento', style: estilo),
        const Spacer(),
        SizedBox(
          width: 110,
          height: 30,
          child: TextField(
            controller: _controlador,
            focusNode: _foco,
            textAlign: TextAlign.right,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: estilo,
            onChanged: (texto) => ref
                .read(posProvider.notifier)
                .cambiarDescuento(int.tryParse(texto) ?? 0),
            decoration: InputDecoration(
              isDense: true,
              hintText: r'– $0',
              hintStyle: TipografiaApp.deshabilitado(estilo),
              prefixText: widget.descuento == 0 ? null : r'– $',
              prefixStyle: estilo,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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

  OutlineInputBorder _borde(Color color) => OutlineInputBorder(
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
  final String valor;

  @override
  Widget build(BuildContext context) {
    final estilo = TipografiaApp.cuerpo.copyWith(
      fontSize: 13,
      color: ColoresApp.textSecondary,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(etiqueta, style: estilo),
        Text(valor, style: estilo),
      ],
    );
  }
}
