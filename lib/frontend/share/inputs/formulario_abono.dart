import 'package:flutter/material.dart';

import '../botones/boton_primario.dart';
import '../botones/boton_secundario.dart';
import '../cards/panel_seccion.dart';
import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';
import 'campo_texto.dart';
import 'selector_widget.dart';

/// Registrar una entrega de dinero contra un documento: el abono de una
/// reserva o el pago de una deuda.
///
/// **Es el mismo formulario en los dos sitios** —monto, método, referencia y
/// «Todo el saldo»—, así que vive aquí en vez de estar copiado en cada
/// módulo. Lo único que cambia son las palabras, y eso entra por parámetro.
///
/// El monto **se acota al saldo**: no se puede recibir más de lo que falta, y
/// el repositorio lo rechazaría igual. Acotarlo aquí evita el viaje y el
/// mensaje rojo; el botón «Todo el saldo» está porque es lo que más se teclea.
///
/// Es genérico en el método de pago por lo mismo que [SelectorWidget] y
/// `CampoBusqueda`: share no importa nada de `backend/`, así que el `enum`
/// real entra como lista y sale por el callback sin que este archivo lo
/// conozca.
///
/// Parámetros:
/// - [saldo]: cuánto falta por pagar. Con cero el formulario se reemplaza por
///   el aviso de [textoSaldado].
/// - [habilitado]: en `false` se ve pero no se toca (documento cerrado).
/// - [metodos] y [metodoInicial]: las formas de pago que se ofrecen.
/// - [constructorEtiqueta]: cómo se llama cada método en pantalla.
/// - [formatearImporte]: normalmente `formatearPrecio`. Entra por parámetro
///   porque share no depende de `intl`.
/// - [alRegistrar]: recibe monto, método y referencia ya validados. La
///   referencia llega en `null` si se dejó vacía.
/// - [titulo], [etiquetaBoton], [iconoBoton]: cómo se llama la acción.
/// - [etiquetaReferencia], [placeholderReferencia]: el campo libre de abajo,
///   que en reservas es la referencia del pago y en deudas una nota.
/// - [textoSaldado]: qué decir cuando ya no queda nada por cobrar.
///
/// Ejemplo:
/// ```dart
/// FormularioAbono<MetodoPago>(
///   saldo: estado.saldo,
///   habilitado: estado.editable,
///   metodos: MetodoPago.paraAbonos,
///   metodoInicial: MetodoPago.efectivo,
///   constructorEtiqueta: (m) => m.etiqueta,
///   formatearImporte: formatearPrecio,
///   alRegistrar: (monto, metodo, referencia) =>
///       notifier.registrarAbono(monto: monto, metodoPago: metodo),
/// )
/// ```
class FormularioAbono<T> extends StatefulWidget {
  const FormularioAbono({
    super.key,
    required this.saldo,
    required this.habilitado,
    required this.metodos,
    required this.metodoInicial,
    required this.constructorEtiqueta,
    required this.formatearImporte,
    required this.alRegistrar,
    this.titulo = 'Registrar abono',
    this.etiquetaBoton = 'Registrar abono',
    this.iconoBoton = Icons.savings_outlined,
    this.etiquetaReferencia = 'Referencia',
    this.placeholderReferencia = 'Opcional: número de transacción…',
    this.textoSaldado = 'No queda saldo: ya está pagado.',
  });

  final int saldo;
  final bool habilitado;
  final List<T> metodos;
  final T metodoInicial;
  final String Function(T metodo) constructorEtiqueta;
  final String Function(int importe) formatearImporte;
  final void Function(int monto, T metodo, String? referencia) alRegistrar;
  final String titulo;
  final String etiquetaBoton;
  final IconData iconoBoton;
  final String etiquetaReferencia;
  final String placeholderReferencia;
  final String textoSaldado;

  @override
  State<FormularioAbono<T>> createState() => _FormularioAbonoState<T>();
}

class _FormularioAbonoState<T> extends State<FormularioAbono<T>> {
  final _monto = TextEditingController();
  final _referencia = TextEditingController();
  late T _metodo = widget.metodoInicial;

  @override
  void dispose() {
    _monto.dispose();
    _referencia.dispose();
    super.dispose();
  }

  int get _valor => int.tryParse(_monto.text) ?? 0;

  bool get _puedeRegistrar =>
      widget.habilitado &&
      widget.saldo > 0 &&
      _valor > 0 &&
      _valor <= widget.saldo;

  void _todoElSaldo() => setState(() => _monto.text = '${widget.saldo}');

  void _registrar() {
    if (!_puedeRegistrar) return;
    final referencia = _referencia.text.trim();
    widget.alRegistrar(
      _valor,
      _metodo,
      referencia.isEmpty ? null : referencia,
    );
    setState(() {
      _monto.clear();
      _referencia.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.saldo <= 0) {
      return PanelSeccion(
        titulo: widget.titulo,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  size: 16, color: ColoresApp.statusSuccess),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.textoSaldado, style: TipografiaApp.caption),
              ),
            ],
          ),
        ),
      );
    }

    final excedido = _valor > widget.saldo;

    return PanelSeccion(
      titulo: widget.titulo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: CampoTexto(
                  etiqueta: 'Monto',
                  controlador: _monto,
                  placeholder: '0',
                  soloEnteros: true,
                  habilitado: widget.habilitado,
                  alCambiar: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: BotonSecundario(
                  etiqueta: 'Todo el saldo',
                  alPresionar: widget.habilitado ? _todoElSaldo : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            excedido
                ? 'Son ${widget.formatearImporte(_valor - widget.saldo)} de '
                    'más: faltan ${widget.formatearImporte(widget.saldo)}.'
                : 'Faltan ${widget.formatearImporte(widget.saldo)} por pagar.',
            style: TipografiaApp.caption.copyWith(
              fontSize: 11.5,
              color:
                  excedido ? ColoresApp.statusDanger : ColoresApp.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          SelectorWidget<T>(
            etiqueta: 'Método de pago',
            valor: _metodo,
            opciones: widget.metodos,
            constructorEtiqueta: widget.constructorEtiqueta,
            habilitado: widget.habilitado,
            alCambiar: (m) => setState(() => _metodo = m),
          ),
          const SizedBox(height: 14),
          CampoTexto(
            etiqueta: widget.etiquetaReferencia,
            controlador: _referencia,
            placeholder: widget.placeholderReferencia,
            habilitado: widget.habilitado,
          ),
          const SizedBox(height: 16),
          BotonPrimario(
            etiqueta: widget.etiquetaBoton,
            icono: widget.iconoBoton,
            expandido: true,
            alPresionar: _puedeRegistrar ? _registrar : null,
          ),
        ],
      ),
    );
  }
}
