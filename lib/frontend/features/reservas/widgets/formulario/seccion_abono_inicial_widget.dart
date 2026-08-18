import 'package:inventario_k1/backend/share/dominio/metodo_pago.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import '../../reserva_editor/provider/reserva_editor_provider.dart';

class SeccionAbonoInicialWidget extends ConsumerStatefulWidget {
  const SeccionAbonoInicialWidget({super.key});

  @override
  ConsumerState<SeccionAbonoInicialWidget> createState() =>
      _SeccionAbonoInicialWidgetState();
}

class _SeccionAbonoInicialWidgetState
    extends ConsumerState<SeccionAbonoInicialWidget> {
  final _montoCtrl = TextEditingController();

  @override
  void dispose() {
    _montoCtrl.dispose();
    super.dispose();
  }

  void _onMontoChanged(String valor) {
    final monto = int.tryParse(valor.replaceAll('.', '')) ?? 0;
    ref.read(reservaEditorProvider.notifier).cambiarAbonoInicial(monto);
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(reservaEditorProvider);
    final notifier = ref.read(reservaEditorProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cabecera(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _CampoLabeled(
                    label: 'Monto del abono',
                    hint: '0',
                    controller: _montoCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: _onMontoChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SelectorMetodoPago(
                    valor: estado.metodoPago,
                    onCambio: (v) => notifier.cambiarMetodoPago(v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CampoLabeled(
                    label: 'Referencia (opc.)',
                    hint: 'Nro. transacción…',
                    onChanged: notifier.cambiarReferencia,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
        border: Border(bottom: BorderSide(color: ColoresApp.border)),
      ),
      child: const Row(
        children: [
          Text(
            'ABONO INICIAL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: ColoresApp.primary,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(width: 8),
          Text(
            '· Deja el monto en 0 si no paga ahora',
            style: TextStyle(
              fontSize: 10,
              color: ColoresApp.textLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _CampoLabeled extends StatelessWidget {
  const _CampoLabeled({
    required this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.onChanged,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

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
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style:
              const TextStyle(fontSize: 13.5, color: ColoresApp.textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                fontSize: 13.5, color: ColoresApp.textLight),
            filled: true,
            fillColor: ColoresApp.bgContent,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
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
              borderSide: const BorderSide(
                  color: ColoresApp.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectorMetodoPago extends StatelessWidget {
  const _SelectorMetodoPago({required this.valor, required this.onCambio});

  final MetodoPago valor;
  final ValueChanged<MetodoPago?> onCambio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MÉTODO DE PAGO',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ColoresApp.textMedium,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<MetodoPago>(
          initialValue: valor,
          onChanged: onCambio,
          style: const TextStyle(fontSize: 13.5, color: ColoresApp.textDark),
          decoration: InputDecoration(
            filled: true,
            fillColor: ColoresApp.bgContent,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
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
              borderSide: const BorderSide(
                  color: ColoresApp.primary, width: 1.5),
            ),
          ),
          items: MetodoPago.paraAbonos
              .map((m) => DropdownMenuItem(value: m, child: Text(m.etiqueta)))
              .toList(),
        ),
      ],
    );
  }
}
