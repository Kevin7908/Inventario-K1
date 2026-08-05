import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/tecnicos/modelo/tecnico.dart';
import '../../../../../backend/features/ventas/ordenes/modelo/orden_tarea.dart';
import '../../../../../backend/features/ventas/servicios/modelo/servicio.dart';
import '../../../../share/temas/colores_app.dart';
import '../../../../share/widgets/input/app_searc_widget.dart';
import '../../../../share/widgets/output/precio_cop_widget.dart';
import '../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../../tecnicos/provider/tecnico_provider.dart';
import '../../../tecnicos/widgets/dialogo_tecnico_widget.dart';
import '../../../ventas/servicios/provider/servicios_provider.dart';
import '../../../ventas/servicios/widgets/dialogo_servicios.dart';
import '../provider/ordenes_provider.dart';

class DialogoAgregarEditarTarea extends ConsumerStatefulWidget {
  const DialogoAgregarEditarTarea({
    super.key,
    required this.ordenId,
    this.tareaAEditar,
  });

  final int ordenId;
  final OrdenTarea? tareaAEditar;

  bool get esEdicion => tareaAEditar != null;

  static Future<void> mostrar(
    BuildContext context, {
    required int ordenId,
    OrdenTarea? tareaAEditar,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoAgregarEditarTarea(
        ordenId: ordenId,
        tareaAEditar: tareaAEditar,
      ),
    );
  }

  @override
  ConsumerState<DialogoAgregarEditarTarea> createState() =>
      _DialogoAgregarEditarTareaState();
}

class _DialogoAgregarEditarTareaState
    extends ConsumerState<DialogoAgregarEditarTarea> {
  final _formKey = GlobalKey<FormState>();

  late final ValueNotifier<Servicio?> _servicioNotifier;
  late final ValueNotifier<Tecnico?> _tecnicoNotifier;
  late final TextEditingController _precioCtrl;
  late final TextEditingController _notasCtrl;
  late bool _completado;

  bool _guardando = false;
  bool _preseleccionado = false;

  @override
  void initState() {
    super.initState();
    final t = widget.tareaAEditar;
    _servicioNotifier = ValueNotifier(null);
    _tecnicoNotifier  = ValueNotifier(null);
    _precioCtrl = TextEditingController(
      text: t != null ? t.precioPactado.toStringAsFixed(0) : '',
    );
    _notasCtrl  = TextEditingController(text: t?.notas ?? '');
    _completado = t?.completado ?? false;
  }

  @override
  void dispose() {
    _servicioNotifier.dispose();
    _tecnicoNotifier.dispose();
    _precioCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_servicioNotifier.value == null) {
      SnackBarMensaje.error(context, 'Selecciona un servicio.');
      return;
    }
    if (_tecnicoNotifier.value == null) {
      SnackBarMensaje.error(context, 'Selecciona un técnico.');
      return;
    }

    setState(() => _guardando = true);

    final notifier = ref.read(ordenesProvider.notifier);
    final precio = double.tryParse(_precioCtrl.text.trim()) ?? 0.0;
    final notas  = _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim();
    String? error;

    if (widget.esEdicion) {
      error = await notifier.actualizarTarea(
        widget.tareaAEditar!.id,
        widget.ordenId,
        servicioId:   _servicioNotifier.value!.id,
        tecnicoId:    _tecnicoNotifier.value!.id!,
        precioPactado: precio,
        notas:         notas,
        completado:    _completado,
      );
    } else {
      error = await notifier.agregarTarea(
        widget.ordenId,
        servicioId:   _servicioNotifier.value!.id,
        tecnicoId:    _tecnicoNotifier.value!.id!,
        precioPactado: precio,
        notas:         notas,
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
        widget.esEdicion ? 'Tarea actualizada.' : 'Tarea agregada.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicios = ref.watch(serviciosProvider).value ?? [];
    final activos   = servicios.where((s) => s.activo).toList();
    final tecnicos  = ref.watch(catalogoTecnicosProvider).value ?? [];

    if (widget.esEdicion && !_preseleccionado && activos.isNotEmpty && tecnicos.isNotEmpty) {
      final t = widget.tareaAEditar!;
      final svc = activos.where((s) => s.id == t.servicioId).firstOrNull;
      if (svc != null) _servicioNotifier.value = svc;
      final tec = tecnicos.where((tc) => tc.id == t.tecnicoId).firstOrNull;
      if (tec != null) _tecnicoNotifier.value = tec;
      _preseleccionado = true;
    }

    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 480,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.80,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildEncabezado(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      _label('Servicio *'),
                      const SizedBox(height: 6),
                      AppSearch<Servicio>(
                        notifier: _servicioNotifier,
                        items: activos,
                        labelBuilder: (s) => s.nombre,
                        hint: 'Seleccionar del catálogo...',
                        validator: (v) =>
                            v == null ? 'Selecciona un servicio.' : null,
                        onAgregar: () =>
                            DialogoServicio.mostrar(context),
                      ),
                      const SizedBox(height: 16),

                      _label('Técnico *'),
                      const SizedBox(height: 6),
                      AppSearch<Tecnico>(
                        notifier: _tecnicoNotifier,
                        items: tecnicos,
                        labelBuilder: (t) => t.nombreCompleto,
                        hint: 'Seleccionar técnico...',
                        validator: (v) =>
                            v == null ? 'Selecciona un técnico.' : null,
                        onAgregar: () =>
                            DialogoTecnico.mostrar(context),
                      ),
                      const SizedBox(height: 16),

                      _label('Precio pactado *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _precioCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        decoration: _inputDeco('0'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Campo requerido.';
                          }
                          final n = double.tryParse(v.trim());
                          if (n == null || n < 0) return 'Valor inválido.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      PrecioCopWidget(
                        controller: _precioCtrl,
                        etiqueta: 'Precio:',
                      ),
                      const SizedBox(height: 16),

                      _label('Notas (opcional)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notasCtrl,
                        maxLines: 3,
                        decoration: _inputDeco(
                            'Ej: Se usó extractor especial, requirió 2h extra...'),
                      ),

                      // Completado — solo en edición
                      if (widget.esEdicion) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Estado de la tarea'),
                                  const SizedBox(height: 2),
                                  Text(
                                    _completado ? 'Completada' : 'Pendiente',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _completado
                                          ? ColoresApp.accentGreen
                                          : ColoresApp.textLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _completado,
                              onChanged: _guardando
                                  ? null
                                  : (v) => setState(() => _completado = v),
                              activeThumbColor: ColoresApp.accentGreen,
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
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
            child: const Icon(Icons.build_outlined,
                color: ColoresApp.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              widget.esEdicion ? 'Editar Tarea' : 'Agregar Tarea',
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
                  : Text(widget.esEdicion ? 'Guardar cambios' : 'Agregar tarea'),
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
