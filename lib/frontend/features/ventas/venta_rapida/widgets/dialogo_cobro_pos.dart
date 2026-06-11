import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../../../../core/currency_ext.dart';
import '../../../../share/temas/colores_app.dart';
import '../../../../share/widgets/output/precio_cop_widget.dart';
import '../../../deudores/dialogo_confirmar_deuda.dart';

export '../../../deudores/dialogo_confirmar_deuda.dart' show DatosDeuda;

const _kBlue  = ColoresApp.primary;
const _kGreen = ColoresApp.accentGreen;
const _kRed   = ColoresApp.accentRed;
const _kAmber = ColoresApp.accentAmber;

// ── DTO resultado del cobro ───────────────────────────────────────────────────

class ResultadoCobro {
  const ResultadoCobro({
    required this.estadoPago,
    required this.totalPagado,
    this.datosDeuda,
  });

  final EstadoPago  estadoPago;
  final double      totalPagado;
  final DatosDeuda? datosDeuda;
}

// ── Diálogo ───────────────────────────────────────────────────────────────────

/// Diálogo de cobro POS.
/// Retorna [ResultadoCobro] con estado pagado/pendiente y datos de deuda si aplica.
/// Retorna null si el usuario cancela.
class DialogoCobrarPOS extends StatefulWidget {
  const DialogoCobrarPOS._({
    required this.total,
    required this.clienteId,
    required this.clienteNombre,
    this.numeroFactura,
  });

  final double  total;
  final int?    clienteId;
  final String? clienteNombre;
  final String? numeroFactura;

  static Future<ResultadoCobro?> mostrar(
    BuildContext context, {
    required double total,
    int?            clienteId,
    String?         clienteNombre,
    String?         numeroFactura,
  }) =>
      showDialog<ResultadoCobro>(
        context: context,
        barrierDismissible: false,
        builder: (_) => DialogoCobrarPOS._(
          total:          total,
          clienteId:      clienteId,
          clienteNombre:  clienteNombre,
          numeroFactura:  numeroFactura,
        ),
      );

  @override
  State<DialogoCobrarPOS> createState() => _DialogoCobrarPOSState();
}

class _DialogoCobrarPOSState extends State<DialogoCobrarPOS> {
  final _recibidoCtrl  = TextEditingController();
  final _resultadoCtrl = TextEditingController(text: '0');

  double  _recibido = 0;
  String? _errorMsg;

  @override
  void dispose() {
    _recibidoCtrl.dispose();
    _resultadoCtrl.dispose();
    super.dispose();
  }

  double get _cambio   => (_recibido - widget.total).clamp(0, double.infinity);
  double get _faltante => (widget.total - _recibido).clamp(0, double.infinity);
  bool   get _completo => _recibido >= widget.total;

  void _actualizarResultado() {
    final v = _recibido == 0 ? 0.0 : (_completo ? _cambio : _faltante);
    _resultadoCtrl.text = v.round().toString();
  }

  Future<void> _onCobrar() async {
    setState(() => _errorMsg = null);

    if (_completo) {
      Navigator.of(context).pop(ResultadoCobro(
        estadoPago:  EstadoPago.pagado,
        totalPagado: widget.total,
      ));
      return;
    }

    if (widget.clienteId == null) {
      setState(() => _errorMsg =
          'Seleccione un cliente para poder registrar la deuda.');
      return;
    }

    final conceptoInicial = widget.numeroFactura != null
        ? 'Deuda — ${widget.numeroFactura}'
        : 'Deuda pendiente';

    final datos = await DialogoConfirmarDeuda.mostrar(
      context,
      clienteNombre:   widget.clienteNombre ?? 'Cliente',
      total:           widget.total,
      recibido:        _recibido,
      faltante:        _faltante,
      conceptoInicial: conceptoInicial,
    );

    if (datos != null && mounted) {
      Navigator.of(context).pop(ResultadoCobro(
        estadoPago:  EstadoPago.pendiente,
        totalPagado: _recibido,
        datosDeuda:  datos,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultadoColor = _recibido == 0
        ? ColoresApp.textLight
        : _completo
            ? _kGreen
            : _kRed;

    final resultadoLabel = _recibido == 0
        ? 'CAMBIO / FALTA'
        : _completo
            ? (_cambio == 0 ? 'PAGO EXACTO' : 'DEVOLVER')
            : 'FALTA';

    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 440,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Título ────────────────────────────────────────────────
              const Text(
                'Cobrar venta',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.textDark,
                ),
              ),
              const SizedBox(height: 20),

              // ── Total a cobrar ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBlue.withValues(alpha: 0.18)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL A COBRAR',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: _kBlue,
                      ),
                    ),
                    Text(
                      widget.total.toCopString(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _kBlue,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── Campo efectivo recibido ───────────────────────────────
              const Text(
                'EFECTIVO RECIBIDO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: ColoresApp.textLight,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller:   _recibidoCtrl,
                autofocus:    true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.textDark),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: ColoresApp.textMedium),
                  hintText: '0',
                  hintStyle: const TextStyle(color: ColoresApp.textLight),
                  filled: true,
                  fillColor: ColoresApp.bgContent,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: const BorderSide(color: ColoresApp.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: const BorderSide(color: ColoresApp.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide:
                          const BorderSide(color: _kBlue, width: 1.5)),
                ),
                onChanged: (v) => setState(() {
                  _recibido = double.tryParse(v.trim()) ?? 0;
                  _errorMsg = null;
                  _actualizarResultado();
                }),
              ),
              const SizedBox(height: 16),

              // ── Dos cajas de precio formateado ────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _CajaPrecio(
                      etiqueta: 'RECIBIDO',
                      color:    _kBlue,
                      child: PrecioCopWidget(
                        controller: _recibidoCtrl,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _kBlue,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CajaPrecio(
                      etiqueta: resultadoLabel,
                      color:    resultadoColor,
                      child: PrecioCopWidget(
                        controller: _resultadoCtrl,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: resultadoColor,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Error sin cliente ─────────────────────────────────────
              if (_errorMsg != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: _kRed.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: _kRed.withValues(alpha: 0.22)),
                  ),
                  child: Text(
                    _errorMsg!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: _kRed,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // ── Acciones ──────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ColoresApp.textMedium,
                        side: const BorderSide(color: ColoresApp.border),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9)),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _onCobrar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _recibido == 0 || _completo ? _kBlue : _kAmber,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9)),
                        textStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      child: Text(
                        _recibido == 0 || _completo
                            ? 'Cobrar'
                            : 'Registrar deuda',
                      ),
                    ),
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

// ── Caja de precio formateado ─────────────────────────────────────────────────

class _CajaPrecio extends StatelessWidget {
  const _CajaPrecio({
    required this.etiqueta,
    required this.color,
    required this.child,
  });

  final String etiqueta;
  final Color  color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: color.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
