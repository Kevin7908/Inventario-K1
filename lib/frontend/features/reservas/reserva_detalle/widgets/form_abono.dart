import 'package:flutter/material.dart';

import '../../../../../backend/share/dominio/metodo_pago.dart';
import '../../../../../core/formato.dart';
import '../../../../share2/share2.dart';

/// Registrar una entrega de dinero contra la reserva.
///
/// El monto **se acota al saldo**: no se puede recibir más de lo que falta, y
/// el repositorio lo rechazaría igual. Acotarlo aquí evita el viaje y el
/// mensaje rojo; el botón «Todo el saldo» está porque es lo que más se teclea.
///
/// Parámetros:
/// - [saldo]: cuánto falta por pagar. Con cero el formulario se apaga.
/// - [habilitado]: en `false` se ve pero no se toca (reserva cerrada).
/// - [alRegistrar]: recibe monto, método y referencia ya validados.
class FormAbono extends StatefulWidget {
  const FormAbono({
    super.key,
    required this.saldo,
    required this.habilitado,
    required this.alRegistrar,
  });

  final int saldo;
  final bool habilitado;
  final void Function(int monto, MetodoPago metodo, String? referencia)
      alRegistrar;

  @override
  State<FormAbono> createState() => _FormAbonoState();
}

class _FormAbonoState extends State<FormAbono> {
  final _monto = TextEditingController();
  final _referencia = TextEditingController();
  MetodoPago _metodo = MetodoPago.efectivo;

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
      return const PanelSeccion(
        titulo: 'Registrar abono',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  size: 16, color: ColoresApp.statusSuccess),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No queda saldo: esta reserva ya está pagada.',
                  style: TipografiaApp.caption,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PanelSeccion(
      titulo: 'Registrar abono',
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
            _valor > widget.saldo
                ? 'Son ${formatearPrecio(_valor - widget.saldo)} de más: '
                    'faltan ${formatearPrecio(widget.saldo)}.'
                : 'Faltan ${formatearPrecio(widget.saldo)} por pagar.',
            style: TipografiaApp.caption.copyWith(
              fontSize: 11.5,
              color: _valor > widget.saldo
                  ? ColoresApp.statusDanger
                  : ColoresApp.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          SelectorWidget<MetodoPago>(
            etiqueta: 'Método de pago',
            valor: _metodo,
            opciones: MetodoPago.paraAbonos,
            constructorEtiqueta: (m) => m.etiqueta,
            habilitado: widget.habilitado,
            alCambiar: (m) => setState(() => _metodo = m),
          ),
          const SizedBox(height: 14),
          CampoTexto(
            etiqueta: 'Referencia',
            controlador: _referencia,
            placeholder: 'Opcional: número de transacción…',
            habilitado: widget.habilitado,
          ),
          const SizedBox(height: 16),
          BotonPrimario(
            etiqueta: 'Registrar abono',
            icono: Icons.savings_outlined,
            alPresionar: _puedeRegistrar ? _registrar : null,
          ),
        ],
      ),
    );
  }
}
