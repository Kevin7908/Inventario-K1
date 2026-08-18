import 'package:inventario_k1/backend/share/dominio/metodo_pago.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import '../../provider/deudor_editor_provider.dart';
import 'seccion_datos_deudor_widget.dart';

class SeccionPagoInicialWidget extends ConsumerStatefulWidget {
  const SeccionPagoInicialWidget({super.key});

  @override
  ConsumerState<SeccionPagoInicialWidget> createState() =>
      _SeccionPagoInicialWidgetState();
}

class _SeccionPagoInicialWidgetState
    extends ConsumerState<SeccionPagoInicialWidget> {
  late final TextEditingController _montoCtrl;
  late final TextEditingController _notasCtrl;

  @override
  void initState() {
    super.initState();
    _montoCtrl = TextEditingController();
    _notasCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(deudorEditorProvider);
    final notifier = ref.read(deudorEditorProvider.notifier);

    return CardFormularioDeudor(
      titulo: 'Abono inicial (opc.)',
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _CampoPagoInicial(
                label: 'Monto',
                controller: _montoCtrl,
                hint: '0',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                mostrarFormato: true,
                onCambio: (v) =>
                    notifier.setPagoInicial(int.tryParse(v) ?? 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _LabelCampoLocal(texto: 'Método'),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<MetodoPago>(
                    initialValue: editor.metodoPagoInicial,
                    style: const TextStyle(
                        fontSize: 13, color: ColoresApp.textDark),
                    decoration: _pagoDecor(),
                    items: MetodoPago.paraAbonos
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m.etiqueta),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        v != null ? notifier.setMetodoPagoInicial(v) : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CampoPagoInicial(
                label: 'Referencia',
                controller: _notasCtrl,
                hint: 'Nro. transacción…',
                onCambio: notifier.setNotasPagoInicial,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampoPagoInicial extends StatefulWidget {
  const _CampoPagoInicial({
    required this.label,
    required this.controller,
    required this.hint,
    required this.onCambio,
    this.keyboardType,
    this.inputFormatters,
    this.mostrarFormato = false,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onCambio;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool mostrarFormato;

  @override
  State<_CampoPagoInicial> createState() => _CampoPagoInicialState();
}

class _CampoPagoInicialState extends State<_CampoPagoInicial> {
  @override
  void initState() {
    super.initState();
    if (widget.mostrarFormato) widget.controller.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    if (widget.mostrarFormato) widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.mostrarFormato
        ? (int.tryParse(widget.controller.text.replaceAll('.', '')) ?? 0)
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabelCampoLocal(texto: widget.label),
        const SizedBox(height: 4),
        TextField(
          controller: widget.controller,
          onChanged: widget.onCambio,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          style: const TextStyle(fontSize: 13, color: ColoresApp.textDark),
          decoration: _pagoDecor(hint: widget.hint),
        ),
        if (widget.mostrarFormato && raw > 0) ...[
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
    );
  }
}

class _LabelCampoLocal extends StatelessWidget {
  const _LabelCampoLocal({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: ColoresApp.textMedium,
        letterSpacing: 0.5,
      ),
    );
  }
}

InputDecoration _pagoDecor({String? hint}) {
  return InputDecoration(
    hintText: hint,
    hintStyle:
        const TextStyle(color: ColoresApp.textLight, fontSize: 13),
    filled: true,
    fillColor: ColoresApp.bgContent,
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
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
      borderSide:
          const BorderSide(color: ColoresApp.primary, width: 1.5),
    ),
  );
}
