import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// El pie de un documento: subtotal, descuento editable, total y, debajo, el
/// IVA que va incluido.
///
/// **Es el único.** El punto de venta, el editor de cotizaciones y el de
/// órdenes tenían cada uno su propio pie —`TotalesVenta`, `TotalesCotizacion`,
/// `TotalesOrden`—, con el mismo renglón, el mismo campo de descuento y la
/// misma línea punteada copiados tres veces. Lo que de verdad cambia entre
/// ellos es de dónde salen los números y quién los recorta, y eso se queda en
/// cada módulo.
///
/// El renglón de IVA va **debajo del total y no encima**, porque no suma: los
/// precios ya lo traen dentro (ver `iva_app.dart`), así que solo dice cuánto
/// del total es impuesto. Si no hay IVA que declarar, se pasa [iva] en `null`
/// y no se pinta: un `$0` solo estorba.
///
/// Los importes llegan **ya formateados**: share no depende de `intl`, así
/// que quien lo usa les pasa `formatearPrecio`.
///
/// El controlador y el foco del descuento **son de quien lo usa**: share no
/// guarda estado, y cada editor tiene su propia regla de cuándo puede pisar lo
/// que se está tecleando (el de órdenes espera la relectura del repositorio;
/// el del punto de venta, el estado en memoria).
///
/// Parámetros:
/// - [subtotal]: importe ya formateado, o `null` para no pintar el renglón.
///   Sin descuento repite al total y suele esconderse.
/// - [total]: importe ya formateado. Es el renglón grande.
/// - [iva]: importe ya formateado del IVA contenido, o `null` si no hay.
/// - [etiquetaIva]: cómo se llama ese renglón ('IVA (19%) incluido').
/// - [controladorDescuento], [focoDescuento]: los del campo editable.
/// - [alCambiarDescuento]: texto crudo del campo; quien lo recibe lo parsea.
/// - [hayDescuento]: en `true` el campo se pinta en ámbar y con el prefijo
///   `–$`, para que la rebaja se vea sin leer el número.
/// - [editable]: en `false` el campo se deshabilita (documento cerrado).
///
/// Ejemplo:
/// ```dart
/// PieTotales(
///   subtotal: hayDescuento ? formatearPrecio(estado.subtotal) : null,
///   total: formatearPrecio(estado.total),
///   iva: hayIva ? formatearPrecio(estado.iva) : null,
///   etiquetaIva: etiquetaIva,
///   controladorDescuento: _controlador,
///   focoDescuento: _foco,
///   hayDescuento: hayDescuento,
///   alCambiarDescuento: (texto) =>
///       notifier.cambiarDescuento(int.tryParse(texto) ?? 0),
/// )
/// ```
class PieTotales extends StatelessWidget {
  const PieTotales({
    super.key,
    required this.total,
    required this.controladorDescuento,
    required this.focoDescuento,
    required this.alCambiarDescuento,
    this.subtotal,
    this.iva,
    this.etiquetaIva = 'IVA incluido',
    this.etiquetaDescuento = 'Descuento',
    this.hayDescuento = false,
    this.editable = true,
  });

  final String total;
  final TextEditingController controladorDescuento;
  final FocusNode focoDescuento;
  final ValueChanged<String> alCambiarDescuento;
  final String? subtotal;
  final String? iva;
  final String etiquetaIva;
  final String etiquetaDescuento;
  final bool hayDescuento;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (subtotal != null) ...[
          _Renglon(etiqueta: 'Subtotal', valor: subtotal!),
          const SizedBox(height: 8),
        ],
        _CampoDescuento(
          etiqueta: etiquetaDescuento,
          controlador: controladorDescuento,
          foco: focoDescuento,
          alCambiar: alCambiarDescuento,
          activo: hayDescuento,
          editable: editable,
        ),
        const SizedBox(height: 12),
        // Línea punteada sobre el total, como en el diseño.
        const _SeparadorPunteado(),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total', style: TipografiaApp.heading3.copyWith(fontSize: 18)),
            Text(
              total,
              style: TipografiaApp.heading3.copyWith(
                fontSize: 18,
                color: ColoresApp.castletonGreen,
              ),
            ),
          ],
        ),
        if (iva != null) ...[
          const SizedBox(height: 6),
          _Renglon(etiqueta: etiquetaIva, valor: iva!),
        ],
      ],
    );
  }
}

/// El renglón del descuento, con su importe editable a la derecha.
///
/// Se escribe **aquí mismo, en el renglón donde se lee**: es un número que se
/// negocia mirando el total, y mandarlo a un campo aparte del formulario
/// obligaba a saltar entre dos sitios para cuadrarlo. El renglón vive siempre,
/// aunque el descuento sea 0, porque si no habría que descubrir dónde se pone.
class _CampoDescuento extends StatelessWidget {
  const _CampoDescuento({
    required this.etiqueta,
    required this.controlador,
    required this.foco,
    required this.alCambiar,
    required this.activo,
    required this.editable,
  });

  final String etiqueta;
  final TextEditingController controlador;
  final FocusNode foco;
  final ValueChanged<String> alCambiar;
  final bool activo;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final estilo = TipografiaApp.cuerpo.copyWith(
      fontSize: 13,
      color: activo ? ColoresApp.statusWarning : ColoresApp.textSecondary,
    );

    return Row(
      children: [
        Text(
          etiqueta,
          style: TipografiaApp.cuerpo.copyWith(
            fontSize: 13,
            color: ColoresApp.textSecondary,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 110,
          height: 30,
          child: TextField(
            controller: controlador,
            focusNode: foco,
            enabled: editable,
            textAlign: TextAlign.right,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: estilo,
            onChanged: alCambiar,
            decoration: InputDecoration(
              isDense: true,
              hintText: r'$0',
              hintStyle: TipografiaApp.deshabilitado(estilo),
              prefixText: activo ? r'–$' : r'$',
              prefixStyle: estilo,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              filled: true,
              fillColor: ColoresApp.bgCard,
              border: _borde(ColoresApp.borderInput),
              enabledBorder: _borde(ColoresApp.borderInput),
              focusedBorder: _borde(ColoresApp.borderFocus),
              disabledBorder: _borde(ColoresApp.border),
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
        final cuantos = (restricciones.maxWidth / (anchoGuion + hueco))
            .floor()
            .clamp(1, 400);

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

/// Un renglón "etiqueta … importe" del pie.
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
