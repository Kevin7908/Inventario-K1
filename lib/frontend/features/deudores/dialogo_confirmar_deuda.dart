import 'package:inventario_k1/backend/share/dominio/metodo_pago.dart';
import 'package:flutter/material.dart';

import '../../share/formateadores/moneda_formateador.dart';
import '../../share/temas/colores_app.dart';

const _kBlue  = ColoresApp.primary;
const _kGreen = ColoresApp.accentGreen;
const _kRed   = ColoresApp.accentRed;

class DatosDeuda {
  const DatosDeuda({
    required this.concepto,
    required this.metodoPago,
    this.fechaVencimiento,
    this.notas,
  });

  final String  concepto;
  final MetodoPago metodoPago;
  /// `null` = sin plazo pactado.
  final DateTime? fechaVencimiento;
  final String? notas;
}
class DialogoConfirmarDeuda extends StatefulWidget {
  const DialogoConfirmarDeuda._({
    required this.clienteNombre,
    required this.total,
    required this.recibido,
    required this.faltante,
    required this.conceptoInicial,
  });

  final String clienteNombre;
  // Pesos enteros, como todo importe del sistema.
  final int total;
  final int recibido;
  final int faltante;
  final String conceptoInicial;

  static Future<DatosDeuda?> mostrar(
    BuildContext context, {
    required String clienteNombre,
    required int total,
    required int recibido,
    required int faltante,
    String conceptoInicial = '',
  }) =>
      showDialog<DatosDeuda>(
        context: context,
        barrierDismissible: false,
        builder: (_) => DialogoConfirmarDeuda._(
          clienteNombre:   clienteNombre,
          total:           total,
          recibido:        recibido,
          faltante:        faltante,
          conceptoInicial: conceptoInicial,
        ),
      );

  @override
  State<DialogoConfirmarDeuda> createState() => _DialogoConfirmarDeudaState();
}

class _DialogoConfirmarDeudaState extends State<DialogoConfirmarDeuda> {
  late final TextEditingController _conceptoCtrl;
  final _notasCtrl = TextEditingController();

  MetodoPago _metodoPago = MetodoPago.efectivo;
  DateTime? _fechaVencimiento;
  String?   _errorConcepto;

  //static const _metodosPago = ['Efectivo', 'Tarjeta', 'Transferencia', 'Crédito'];

  @override
  void initState() {
    super.initState();
    _conceptoCtrl = TextEditingController(text: widget.conceptoInicial);
  }

  @override
  void dispose() {
    _conceptoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate:   DateTime.now(),
      lastDate:    DateTime.now().add(const Duration(days: 365 * 3)),
      helpText:    'Fecha de vencimiento',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _kBlue),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _fechaVencimiento = picked);
  }

  void _confirmar() {
    final concepto = _conceptoCtrl.text.trim();
    if (concepto.isEmpty) {
      setState(() => _errorConcepto = 'El concepto es obligatorio.');
      return;
    }

    Navigator.of(context).pop(DatosDeuda(
      concepto:         concepto,
      metodoPago:       _metodoPago,
      fechaVencimiento: _fechaVencimiento,
      notas: _notasCtrl.text.trim().isNotEmpty ? _notasCtrl.text.trim() : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final fechaLabel = _fechaVencimiento == null
        ? 'Sin vencimiento'
        : '${_fechaVencimiento!.day.toString().padLeft(2, '0')}/'
          '${_fechaVencimiento!.month.toString().padLeft(2, '0')}/'
          '${_fechaVencimiento!.year}';

    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Encabezado ────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kRed.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined,
                        color: _kRed, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registrar deuda pendiente',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ColoresApp.textDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'El cliente no cubrió el monto completo.',
                        style: TextStyle(fontSize: 12.5, color: ColoresApp.textMedium),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Tarjeta resumen ───────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: ColoresApp.bgContent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ColoresApp.border),
                ),
                child: Column(
                  children: [
                    _FilaResumen(
                      label: 'Cliente',
                      valor: widget.clienteNombre,
                      valorBold: true,
                      valorColor: _kBlue,
                    ),
                    const Divider(height: 1, color: ColoresApp.border),
                    _FilaResumen(label: 'Total factura', valor: fmtMoneda(widget.total)),
                    const Divider(height: 1, color: ColoresApp.border),
                    _FilaResumen(
                      label: 'Recibido',
                      valor: fmtMoneda(widget.recibido),
                      valorColor: _kGreen,
                    ),
                    const Divider(height: 1, color: ColoresApp.border),
                    _FilaResumen(
                      label: 'Deuda a registrar',
                      valor: fmtMoneda(widget.faltante),
                      valorBold: true,
                      valorColor: _kRed,
                      fondo: _kRed.withValues(alpha: 0.04),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── Concepto ──────────────────────────────────────────────
              const _LabelCampo('CONCEPTO *'),
              const SizedBox(height: 5),
              TextField(
                controller: _conceptoCtrl,
                maxLength:  120,
                style: const TextStyle(fontSize: 13, color: ColoresApp.textDark),
                decoration: _inputDeco(
                  hint:  'Descripción de la deuda',
                  error: _errorConcepto,
                ),
                onChanged: (_) {
                  if (_errorConcepto != null) setState(() => _errorConcepto = null);
                },
              ),
              const SizedBox(height: 14),

              // ── Método de pago + Fecha ────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _LabelCampo('MÉTODO DE PAGO'),
                        const SizedBox(height: 5),
                        DropdownButtonFormField<MetodoPago>(
                          initialValue: _metodoPago,
                          items: MetodoPago.paraAbonos
                              .map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(m.etiqueta),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _metodoPago = v!),
                          style: const TextStyle(fontSize: 13, color: ColoresApp.textDark),
                          decoration: _inputDeco(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _LabelCampo('VENCIMIENTO (OPCIONAL)'),
                        const SizedBox(height: 5),
                        InkWell(
                          onTap: _seleccionarFecha,
                          borderRadius: BorderRadius.circular(9),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 13),
                            decoration: BoxDecoration(
                              color: ColoresApp.bgContent,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: _fechaVencimiento != null
                                    ? _kBlue.withValues(alpha: 0.5)
                                    : ColoresApp.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 14,
                                  color: _fechaVencimiento != null
                                      ? _kBlue
                                      : ColoresApp.textLight,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  fechaLabel,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: _fechaVencimiento != null
                                        ? ColoresApp.textDark
                                        : ColoresApp.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_fechaVencimiento != null) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => setState(() => _fechaVencimiento = null),
                            child: const Text(
                              'Quitar fecha',
                              style: TextStyle(
                                fontSize: 11,
                                color: _kBlue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Notas ─────────────────────────────────────────────────
              const _LabelCampo('NOTAS (OPCIONAL)'),
              const SizedBox(height: 5),
              TextField(
                controller: _notasCtrl,
                maxLines:   2,
                style: const TextStyle(fontSize: 13, color: ColoresApp.textDark),
                decoration: _inputDeco(hint: 'Acuerdos de pago, observaciones…'),
              ),
              const SizedBox(height: 16),

              // ── Nota azul ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBlue.withValues(alpha: 0.18)),
                ),
                child: const Text(
                  'La factura quedará en estado Pendiente. La deuda aparecerá en el módulo de Deudores.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // ── Botones ───────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ColoresApp.textMedium,
                        side: const BorderSide(color: ColoresApp.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                      onPressed: _confirmar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9)),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Confirmar deuda'),
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

  InputDecoration _inputDeco({String? hint, String? error}) {
    return InputDecoration(
      hintText: hint,
      errorText: error,
      hintStyle: const TextStyle(color: ColoresApp.textLight, fontSize: 13),
      filled: true,
      fillColor: ColoresApp.bgContent,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: ColoresApp.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: ColoresApp.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: _kBlue, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: _kRed)),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _LabelCampo extends StatelessWidget {
  const _LabelCampo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Text(
        texto,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: ColoresApp.textLight,
        ),
      );
}

class _FilaResumen extends StatelessWidget {
  const _FilaResumen({
    required this.label,
    required this.valor,
    this.valorColor,
    this.valorBold = false,
    this.fondo,
  });

  final String label;
  final String valor;
  final Color? valorColor;
  final bool   valorBold;
  final Color? fondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: fondo,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: ColoresApp.textMedium)),
          const Spacer(),
          Text(
            valor,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: valorBold ? FontWeight.w700 : FontWeight.w500,
              color: valorColor ?? ColoresApp.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
