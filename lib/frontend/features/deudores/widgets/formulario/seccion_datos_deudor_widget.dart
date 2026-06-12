import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/backend/features/clientes/modelo/cliente.dart';
import 'package:inventario_k1/backend/features/deudores/enum/enum_deudor.dart';
import 'package:inventario_k1/frontend/features/clientes/widget/dialogo_cliente_widget.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/widgets/input/app_searc_widget.dart';

import '../../provider/deudor_editor_provider.dart';
import '../../provider/deudores_provider.dart';

class SeccionDatosDeudorWidget extends ConsumerStatefulWidget {
  const SeccionDatosDeudorWidget({super.key});

  @override
  ConsumerState<SeccionDatosDeudorWidget> createState() =>
      _SeccionDatosDeudorWidgetState();
}

class _SeccionDatosDeudorWidgetState
    extends ConsumerState<SeccionDatosDeudorWidget> {
  late final TextEditingController _conceptoCtrl;
  late final TextEditingController _montoCtrl;
  late final TextEditingController _notasCtrl;

  @override
  void initState() {
    super.initState();
    final s = ref.read(deudorEditorProvider);
    _conceptoCtrl = TextEditingController(text: s.concepto);
    _montoCtrl = TextEditingController(
        text: s.montoTotal > 0 ? s.montoTotal.toString() : '');
    _notasCtrl = TextEditingController(text: s.notas);
  }

  @override
  void dispose() {
    _conceptoCtrl.dispose();
    _montoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(deudorEditorProvider);
    final notifier = ref.read(deudorEditorProvider.notifier);

    return _CardFormulario(
      titulo: 'Datos del deudor',
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _SelectorCliente(
                    clienteId: editor.clienteId,
                    clienteNombre: editor.clienteNombre,
                    onSeleccionado: notifier.setCliente,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CampoMonto(
                    controller: _montoCtrl,
                    onCambio: (v) =>
                        notifier.setMontoTotal(int.tryParse(v) ?? 0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CampoTexto(
              label: 'Concepto',
              controller: _conceptoCtrl,
              hint: 'Describe la deuda brevemente…',
              onCambio: notifier.setConcepto,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _SelectorFechaVencimiento(
                    valor: editor.fechaVencimiento,
                    onCambio: notifier.setFechaVencimiento,
                  ),
                ),
                const SizedBox(width: 12),
                if (editor.esEdicion)
                  Expanded(
                    child: _SelectorEstado(
                      valor: editor.estado,
                      onCambio: notifier.setEstado,
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 12),
            _CampoTexto(
              label: 'Notas internas',
              controller: _notasCtrl,
              hint: 'Acuerdos, compromisos, contexto…',
              onCambio: notifier.setNotas,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Selector de cliente ───────────────────────────────────────────────────────

class _SelectorCliente extends ConsumerStatefulWidget {
  const _SelectorCliente({
    required this.clienteId,
    required this.clienteNombre,
    required this.onSeleccionado,
  });

  final int? clienteId;
  final String clienteNombre;
  final void Function(int id, String nombre) onSeleccionado;

  @override
  ConsumerState<_SelectorCliente> createState() => _SelectorClienteState();
}

class _SelectorClienteState extends ConsumerState<_SelectorCliente> {
  final _notifier = ValueNotifier<Cliente?>(null);

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  String _nombreCliente(Cliente c) =>
      '${c.nombres} ${c.apellidos ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clientesParaDeudorProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _LabelCampo(texto: 'Cliente *'),
        const SizedBox(height: 4),
        clientesAsync.when(
          loading: () => const SizedBox(
            height: 42,
            child: Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: ColoresApp.primary),
            ),
          ),
          error: (e, _) => Text(
            'Error: $e',
            style: const TextStyle(
                fontSize: 12, color: ColoresApp.statusDebt),
          ),
          data: (clientes) {
            // Inicializa el notifier cuando se edita y aún no está asignado
            if (_notifier.value == null && widget.clienteId != null) {
              final match = clientes
                  .where((c) => c.id == widget.clienteId);
              if (match.isNotEmpty) _notifier.value = match.first;
            }
            return AppSearch<Cliente>(
              notifier: _notifier,
              items: clientes,
              labelBuilder: _nombreCliente,
              hint: 'Buscar cliente…',
              onAgregar: () async {
                await DialogoCliente.mostrar(context);
                ref.invalidate(clientesParaDeudorProvider);
              },
              onChanged: (cliente) {
                if (cliente == null) return;
                widget.onSeleccionado(cliente.id, _nombreCliente(cliente));
              },
            );
          },
        ),
      ],
    );
  }
}

// ── Campos de texto ───────────────────────────────────────────────────────────

class _CampoTexto extends StatelessWidget {
  const _CampoTexto({
    required this.label,
    required this.controller,
    required this.hint,
    required this.onCambio,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onCambio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabelCampo(texto: label),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onChanged: onCambio,
          style: const TextStyle(fontSize: 13, color: ColoresApp.textDark),
          decoration: _formDecor(hint: hint),
        ),
      ],
    );
  }
}

class _CampoMonto extends StatelessWidget {
  const _CampoMonto(
      {required this.controller, required this.onCambio});

  final TextEditingController controller;
  final ValueChanged<String> onCambio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _LabelCampo(texto: 'Monto total *'),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onChanged: onCambio,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 13, color: ColoresApp.textDark),
          decoration: _formDecor(hint: '0'),
        ),
        const SizedBox(height: 2),
        const Text(
          'En pesos colombianos',
          style: TextStyle(fontSize: 10, color: ColoresApp.textLight),
        ),
      ],
    );
  }
}

// ── Selector de fecha ─────────────────────────────────────────────────────────

class _SelectorFechaVencimiento extends StatefulWidget {
  const _SelectorFechaVencimiento({
    required this.valor,
    required this.onCambio,
  });

  final String? valor;
  final ValueChanged<String?> onCambio;

  @override
  State<_SelectorFechaVencimiento> createState() =>
      _SelectorFechaVencimientoState();
}

class _SelectorFechaVencimientoState
    extends State<_SelectorFechaVencimiento> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.valor ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final initial = widget.valor != null
        ? DateTime.tryParse(widget.valor!) ?? DateTime.now()
        : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final formatted =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    _ctrl.text = formatted;
    widget.onCambio(formatted);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _LabelCampo(texto: 'Fecha de vencimiento'),
        const SizedBox(height: 4),
        TextField(
          controller: _ctrl,
          readOnly: true,
          onTap: _seleccionarFecha,
          style: const TextStyle(fontSize: 13, color: ColoresApp.textDark),
          decoration: _formDecor(
            hint: 'YYYY-MM-DD',
            suffix: const Icon(Icons.calendar_today_outlined,
                size: 16, color: ColoresApp.textMedium),
          ),
        ),
      ],
    );
  }
}

// ── Selector de estado ────────────────────────────────────────────────────────

class _SelectorEstado extends StatelessWidget {
  const _SelectorEstado({required this.valor, required this.onCambio});

  final EstadoDeudor valor;
  final ValueChanged<EstadoDeudor> onCambio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _LabelCampo(texto: 'Estado'),
        const SizedBox(height: 4),
        DropdownButtonFormField<EstadoDeudor>(
          initialValue: valor,
          style: const TextStyle(fontSize: 13, color: ColoresApp.textDark),
          decoration: _formDecor(),
          items: EstadoDeudor.values
              .map((e) =>
                  DropdownMenuItem(value: e, child: Text(e.valor)))
              .toList(),
          onChanged: (v) => v != null ? onCambio(v) : null,
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _LabelCampo extends StatelessWidget {
  const _LabelCampo({required this.texto});

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

InputDecoration _formDecor({String? hint, Widget? suffix}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: ColoresApp.textLight, fontSize: 13),
    filled: true,
    fillColor: ColoresApp.bgContent,
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
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

// ── Card del formulario (compartida en esta sección) ──────────────────────────

class _CardFormulario extends StatelessWidget {
  const _CardFormulario(
      {required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresApp.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: const BoxDecoration(
              color: ColoresApp.primaryLight,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Text(
              titulo.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ColoresApp.primaryDark,
                letterSpacing: 0.8,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// Exportamos _CardFormulario como público para seccion_pago_inicial
class CardFormularioDeudor extends StatelessWidget {
  const CardFormularioDeudor(
      {super.key, required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      _CardFormulario(titulo: titulo, child: child);
}
