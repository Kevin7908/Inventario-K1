import 'package:flutter/material.dart';

import '../../../../backend/features/pos/enum/enum_ventas.dart';
import '../../../../core/formato.dart';
import '../../../../core/validaciones.dart';
import '../../../share/share.dart';

/// Cuadro de cobro del punto de venta: cómo paga el cliente y, si es en
/// efectivo, cuánto entregó y cuánto hay que devolverle.
///
/// La forma de pago se elige aquí y no en el carrito porque es lo último que
/// se sabe: el cliente lo dice al momento de pagar. Devuelve el método
/// elegido, o `null` si se cancela.
///
/// **No hay pago parcial ni deuda**: toda venta de mostrador se cobra
/// completa. Fiar se registra en Cuentas por cobrar, con el cliente delante.
///
/// El vuelto es una ayuda de caja, no un dato que se guarde: lo que queda en
/// la factura es que se pagó el total.
class DialogoCobro extends StatefulWidget {
  const DialogoCobro({super.key, required this.total});

  final int total;

  static Future<MetodoPago?> mostrar(
    BuildContext context, {
    required int total,
  }) {
    return showDialog<MetodoPago>(
      context: context,
      builder: (_) => DialogoCobro(total: total),
    );
  }

  /// Crédito queda fuera: implicaría una venta sin pagar, que es justo lo que
  /// este cuadro no hace.
  static const List<MetodoPago> metodos = [
    MetodoPago.efectivo,
    MetodoPago.tarjeta,
    MetodoPago.transferencia,
  ];

  @override
  State<DialogoCobro> createState() => _DialogoCobroState();
}

class _DialogoCobroState extends State<DialogoCobro> {
  final _recibido = TextEditingController();

  MetodoPago _metodo = MetodoPago.efectivo;
  int _entregado = 0;

  bool get _esEfectivo => _metodo == MetodoPago.efectivo;

  /// En efectivo no se puede cobrar con menos plata de la que vale la venta.
  /// Con tarjeta o transferencia el monto lo mueve el datáfono, no la caja.
  bool get _sePuedeCobrar => !_esEfectivo || _entregado >= widget.total;

  int get _cambio => _entregado - widget.total;

  @override
  void dispose() {
    _recibido.dispose();
    super.dispose();
  }

  void _cobrar() {
    if (!_sePuedeCobrar) return;
    Navigator.of(context).pop(_metodo);
  }

  @override
  Widget build(BuildContext context) {
    return AtajosFormulario(
      alGuardar: _cobrar,
      alCancelar: () => Navigator.of(context).pop(),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ColoresApp.bgCard,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: ColoresApp.shadowMedium,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Cobrar la venta', style: TipografiaApp.heading3),
              const SizedBox(height: 18),
              _TotalDestacado(total: widget.total),
              const SizedBox(height: 20),
              const Text('Forma de pago', style: TipografiaApp.etiquetaCampo),
              const SizedBox(height: 7),
              _SelectorMetodo(
                actual: _metodo,
                alCambiar: (metodo) => setState(() => _metodo = metodo),
              ),
              if (_esEfectivo) ...[
                const SizedBox(height: 16),
                _CampoRecibido(
                  controlador: _recibido,
                  alCambiar: (valor) => setState(() => _entregado = valor),
                ),
                const SizedBox(height: 12),
                _Cambio(valor: _cambio, alcanza: _sePuedeCobrar),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancelar',
                      style: TipografiaApp.cuerpoMedium.copyWith(
                        color: ColoresApp.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  BotonPrimario(
                    etiqueta: 'Cobrar',
                    icono: Icons.point_of_sale_outlined,
                    alPresionar: _sePuedeCobrar ? _cobrar : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lo que hay que cobrar, en grande: es el número que se dice en voz alta.
class _TotalDestacado extends StatelessWidget {
  const _TotalDestacado({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ColoresApp.statusSuccessBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total a pagar',
            style: TipografiaApp.cuerpoMedium.copyWith(
              color: ColoresApp.castletonGreen,
            ),
          ),
          Text(
            formatearPrecio(total),
            style: TipografiaApp.heading2.copyWith(
              color: ColoresApp.castletonGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectorMetodo extends StatelessWidget {
  const _SelectorMetodo({required this.actual, required this.alCambiar});

  final MetodoPago actual;
  final ValueChanged<MetodoPago> alCambiar;

  @override
  Widget build(BuildContext context) {
    // Chips a su ancho natural, como los del diseño. Estirados a tercios el
    // texto queda descolgado a la izquierda de su caja.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final metodo in DialogoCobro.metodos)
          ChipFiltro(
            etiqueta: metodo.etiqueta,
            seleccionado: metodo == actual,
            alPresionar: () => alCambiar(metodo),
          ),
      ],
    );
  }
}

/// Con cuánto paga el cliente.
///
/// Es `CampoTexto` de share y no un `TextField` propio: antes duplicaba el
/// borde, el relleno y el prefijo `$` a mano, y aun así no agrupaba los miles,
/// así que en el mismo diálogo el total salía «$85.000» y lo recibido
/// «85000». Con `comoPrecio` los dos se leen igual.
class _CampoRecibido extends StatelessWidget {
  const _CampoRecibido({required this.controlador, required this.alCambiar});

  final TextEditingController controlador;
  final ValueChanged<int> alCambiar;

  @override
  Widget build(BuildContext context) {
    return CampoTexto(
      etiqueta: 'Recibido',
      controlador: controlador,
      placeholder: 'Con cuánto paga',
      comoPrecio: true,
      autofocus: true,
      alCambiar: (texto) =>
          alCambiar(int.tryParse(normalizarDigitos(texto)) ?? 0),
    );
  }
}

/// El vuelto, o el aviso de que todavía falta plata.
class _Cambio extends StatelessWidget {
  const _Cambio({required this.valor, required this.alcanza});

  final int valor;
  final bool alcanza;

  @override
  Widget build(BuildContext context) {
    final color = alcanza ? ColoresApp.statusSuccess : ColoresApp.statusWarning;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          alcanza ? 'Cambio' : 'Falta',
          style: TipografiaApp.cuerpo.copyWith(color: ColoresApp.textSecondary),
        ),
        Text(
          formatearPrecio(valor.abs()),
          style: TipografiaApp.cuerpoMedium.copyWith(fontSize: 15, color: color),
        ),
      ],
    );
  }
}
