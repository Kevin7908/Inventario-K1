import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/motos/modelo/moto.dart';
import '../../../../../backend/features/ventas/ordenes/enum/enum_ordenes.dart';
import '../../../../../backend/features/ventas/ordenes/modelo/orden_detalle.dart';
import '../../../../share/temas/colores_app.dart';
import '../../../../share/widgets/input/app_searc_widget.dart';
import '../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../../motos/provider/motos_provider.dart';
import '../../../motos/widgets/dialogo_motos.dart';
import '../provider/ordenes_provider.dart';

class DialogoCrearEditarOrden extends ConsumerStatefulWidget {
  const DialogoCrearEditarOrden({super.key, this.ordenAEditar});

  final OrdenDetalle? ordenAEditar;

  bool get esEdicion => ordenAEditar != null;

  static Future<void> mostrar(BuildContext context, {OrdenDetalle? ordenAEditar}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoCrearEditarOrden(ordenAEditar: ordenAEditar),
    );
  }

  @override
  ConsumerState<DialogoCrearEditarOrden> createState() =>
      _DialogoCrearEditarOrdenState();
}

class _DialogoCrearEditarOrdenState
    extends ConsumerState<DialogoCrearEditarOrden> {
  final _formKey = GlobalKey<FormState>();

  late final ValueNotifier<Moto?> _motoNotifier;
  late final TextEditingController _kmCtrl;
  late final TextEditingController _diagnosticoCtrl;
  late final TextEditingController _observacionesCtrl;
  late EstadoOrden _estado;

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _motoNotifier      = ValueNotifier(null);
    _kmCtrl            = TextEditingController(
      text: widget.ordenAEditar?.kilometrajeEntrada.toString() ?? '',
    );
    _diagnosticoCtrl   = TextEditingController(
      text: widget.ordenAEditar?.diagnosticoCliente ?? '',
    );
    _observacionesCtrl = TextEditingController(
      text: widget.ordenAEditar?.observacionesMecanico ?? '',
    );
    _estado = widget.ordenAEditar?.estado ?? EstadoOrden.abierta;
  }

  @override
  void dispose() {
    _motoNotifier.dispose();
    _kmCtrl.dispose();
    _diagnosticoCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_motoNotifier.value == null) {
      SnackBarMensaje.error(context, 'Selecciona una moto.');
      return;
    }

    setState(() => _guardando = true);

    final notifier = ref.read(ordenesProvider.notifier);
    String? error;

    if (widget.esEdicion) {
      error = await notifier.actualizarOrden(
        widget.ordenAEditar!.id,
        estado: _estado,
        diagnostico: _diagnosticoCtrl.text.trim().isEmpty
            ? null
            : _diagnosticoCtrl.text.trim(),
        observaciones: _observacionesCtrl.text.trim().isEmpty
            ? null
            : _observacionesCtrl.text.trim(),
      );
    } else {
      error = await notifier.agregar(
        motoId:             _motoNotifier.value!.id,
        clienteId:          _motoNotifier.value!.clienteId,
        kilometrajeEntrada: int.parse(_kmCtrl.text.trim()),
        diagnostico: _diagnosticoCtrl.text.trim().isEmpty
            ? null
            : _diagnosticoCtrl.text.trim(),
        observaciones: _observacionesCtrl.text.trim().isEmpty
            ? null
            : _observacionesCtrl.text.trim(),
      );
    }

    if (!mounted) return;

    if (error != null) {
      SnackBarMensaje.error(context, error);
      setState(() => _guardando = false);
    } else {
      Navigator.of(context).pop();
      SnackBarMensaje.success(
        context,
        widget.esEdicion ? 'Orden actualizada.' : 'Orden creada correctamente.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final todasLasMotos = ref.watch(motosProvider).value?.motos
            .where((m) => m.activo)
            .toList(growable: false) ??
        const [];

    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 520,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Encabezado
            _buildEncabezado(),
            // Formulario
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Solo en creación: Moto → Cliente (auto)
                      if (!widget.esEdicion) ...[
                        _label('Moto *'),
                        const SizedBox(height: 6),
                        AppSearch<Moto>(
                          notifier: _motoNotifier,
                          items: todasLasMotos,
                          labelBuilder: (m) =>
                              '${m.nombreDisplay}${m.nombreCliente != null ? ' · ${m.nombreCliente}' : ''}',
                          hint: 'Seleccionar moto...',
                          validator: (v) =>
                              v == null ? 'Selecciona una moto.' : null,
                          onAgregar: () => DialogoMoto.mostrar(context),
                        ),
                        const SizedBox(height: 16),
                        _label('Cliente (dueño de la moto)'),
                        const SizedBox(height: 6),
                        ValueListenableBuilder<Moto?>(
                          valueListenable: _motoNotifier,
                          builder: (context, moto, child) => TextFormField(
                            enabled: false,
                            controller: TextEditingController(
                              text: moto?.nombreCliente ?? '',
                            ),
                            decoration: _inputDeco(
                              'Se completará al seleccionar una moto',
                            ).copyWith(
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                size: 18,
                                color: ColoresApp.textLight,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Kilometraje
                      _label('Km de entrada *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _kmCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _inputDeco('Ej: 15420'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Campo requerido.';
                          final n = int.tryParse(v.trim());
                          if (n == null || n < 0) return 'Ingresa un número válido.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Estado (solo edición)
                      if (widget.esEdicion) ...[
                        _label('Estado'),
                        const SizedBox(height: 6),
                        _DropdownEstado(
                          valor: _estado,
                          onChanged: (e) => setState(() => _estado = e),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Diagnóstico
                      _label('Diagnóstico del cliente'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _diagnosticoCtrl,
                        maxLines: 3,
                        decoration: _inputDeco(
                            'Describe el problema o motivo de ingreso...'),
                      ),
                      const SizedBox(height: 16),

                      // Observaciones
                      _label('Observaciones del mecánico'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _observacionesCtrl,
                        maxLines: 3,
                        decoration:
                            _inputDeco('Notas iniciales al recibir la moto...'),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
            // Botones
            _buildBotones(),
          ],
        ),
      ),
    );
  }

  Widget _buildEncabezado() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 20, 0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ColoresApp.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment_outlined,
                color: ColoresApp.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              widget.esEdicion ? 'Editar Orden' : 'Nueva Orden de Servicio',
              style: const TextStyle(
                color: ColoresApp.textDark,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: _guardando ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: ColoresApp.textMedium),
            style: IconButton.styleFrom(
              backgroundColor: ColoresApp.bgContent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotones() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed:
                  _guardando ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: ColoresApp.textMedium,
                side: const BorderSide(color: ColoresApp.border),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: ColoresApp.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(widget.esEdicion ? 'Guardar cambios' : 'Crear orden'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String texto) => Text(
        texto,
        style: const TextStyle(
          color: ColoresApp.textDark,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: ColoresApp.textLight, fontSize: 13.5),
        filled: true,
        fillColor: ColoresApp.bgContent,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ColoresApp.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ColoresApp.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: ColoresApp.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ColoresApp.statusDebt)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: ColoresApp.statusDebt, width: 1.5)),
      );
}

// Dropdown de estado reutilizable
class _DropdownEstado extends StatelessWidget {
  const _DropdownEstado({required this.valor, required this.onChanged});

  final EstadoOrden valor;
  final ValueChanged<EstadoOrden> onChanged;

  static const _colores = {
    EstadoOrden.abierta:   Color(0xFF6366F1),
    EstadoOrden.lista:     Color(0xFF10B981),
    EstadoOrden.entregada: Color(0xFF6B7280),
    EstadoOrden.anulada:   Color(0xFFEF4444),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresApp.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<EstadoOrden>(
          value: valor,
          isExpanded: true,
          style: const TextStyle(
              color: ColoresApp.textDark,
              fontSize: 13.5,
              fontWeight: FontWeight.w500),
          items: EstadoOrden.values.map((e) {
            final color = _colores[e]!;
            return DropdownMenuItem(
              value: e,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(e.etiqueta,
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }).toList(),
          onChanged: (e) {
            if (e != null) onChanged(e);
          },
        ),
      ),
    );
  }
}
