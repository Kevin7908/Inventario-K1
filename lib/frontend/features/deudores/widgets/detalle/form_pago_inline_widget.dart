import 'package:inventario_k1/backend/share/dominio/metodo_pago.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/widgets/output/snack_bar_mensaje.dart';

import '../../provider/deudores_provider.dart';

class FormPagoInlineWidget extends ConsumerStatefulWidget {
  const FormPagoInlineWidget({
    super.key,
    required this.deudorId,
    required this.saldo,
    this.onCancelar,
  });

  final int deudorId;
  final int saldo;
  final VoidCallback? onCancelar;

  @override
  ConsumerState<FormPagoInlineWidget> createState() =>
      _FormPagoInlineWidgetState();
}

class _FormPagoInlineWidgetState extends ConsumerState<FormPagoInlineWidget> {
  final _montoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  MetodoPago _metodoPago = MetodoPago.efectivo;
  bool _guardando = false;

  @override
  void dispose() {
    _montoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final monto = int.tryParse(_montoCtrl.text.replaceAll('.', '')) ?? 0;
    if (monto <= 0) {
      SnackBarMensaje.error(context, 'Ingresa un monto válido.');
      return;
    }
    if (monto > widget.saldo) {
      SnackBarMensaje.error(
          context, 'El pago no puede superar el saldo pendiente.');
      return;
    }
    setState(() => _guardando = true);
    final error = await ref.read(deudoresProvider.notifier).registrarPago(
          deudorId: widget.deudorId,
          monto: monto,
          metodoPago: _metodoPago,
          notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() => _guardando = false);
    if (error != null) {
      SnackBarMensaje.error(context, error);
    } else {
      SnackBarMensaje.success(context, 'Pago registrado correctamente.');
      _montoCtrl.clear();
      _notasCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresApp.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresApp.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REGISTRAR PAGO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ColoresApp.primary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _CampoMonto(controller: _montoCtrl)),
              const SizedBox(width: 10),
              Expanded(
                child: _SelectorMetodo(
                  valor: _metodoPago,
                  onCambio: (v) => setState(() => _metodoPago = v!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _CampoNotas(controller: _notasCtrl)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => widget.onCancelar != null
                    ? widget.onCancelar!()
                    : ref.read(deudoresProvider.notifier).toggleFormPago(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColoresApp.textMedium,
                  side: const BorderSide(color: ColoresApp.border),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 13),
                ),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text('Guardar pago'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColoresApp.statusPaid,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Campos internos ───────────────────────────────────────────────────────────

class _CampoMonto extends StatefulWidget {
  const _CampoMonto({required this.controller});

  final TextEditingController controller;

  @override
  State<_CampoMonto> createState() => _CampoMontoState();
}

class _CampoMontoState extends State<_CampoMonto> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final raw =
        int.tryParse(widget.controller.text.replaceAll('.', '')) ?? 0;
    return _CampoFormPago(
      label: 'Monto *',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13, color: ColoresApp.textDark),
            decoration: _deudorInputDecor(hint: '0'),
          ),
          if (raw > 0) ...[
            const SizedBox(height: 3),
            Text(
              raw.toCopString(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ColoresApp.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectorMetodo extends StatelessWidget {
  const _SelectorMetodo({required this.valor, required this.onCambio});

  final MetodoPago valor;
  final ValueChanged<MetodoPago?> onCambio;

  @override
  Widget build(BuildContext context) {
    return _CampoFormPago(
      label: 'Método',
      child: DropdownButtonFormField<MetodoPago>(
        initialValue: valor,
        onChanged: onCambio,
        style: const TextStyle(fontSize: 13, color: ColoresApp.textDark),
        decoration: _deudorInputDecor(),
        items: MetodoPago.paraAbonos
            .map((m) => DropdownMenuItem(value: m, child: Text(m.etiqueta)))
            .toList(),
      ),
    );
  }
}

class _CampoNotas extends StatelessWidget {
  const _CampoNotas({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _CampoFormPago(
      label: 'Referencia (opc.)',
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 13, color: ColoresApp.textDark),
        decoration: _deudorInputDecor(hint: 'Nro. transacción…'),
      ),
    );
  }
}

class _CampoFormPago extends StatelessWidget {
  const _CampoFormPago({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ColoresApp.textMedium,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

InputDecoration _deudorInputDecor({String? hint}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: ColoresApp.textLight, fontSize: 13),
    filled: true,
    fillColor: ColoresApp.bgCard,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: ColoresApp.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: ColoresApp.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: ColoresApp.primary, width: 1.5),
    ),
  );
}
