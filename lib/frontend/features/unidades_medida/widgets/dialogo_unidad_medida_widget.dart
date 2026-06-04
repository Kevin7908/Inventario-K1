import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import '../../../../backend/features/unidades_medida/modelo/unidad_medida.dart';
import '../../../share/widgets/output/snack_bar_mensaje.dart';
import '../provider/unidades_medida_provider.dart';

class DialogoUnidadMedida extends ConsumerStatefulWidget {
  final UnidadMedida? unidadAEditar;

  const DialogoUnidadMedida({super.key, this.unidadAEditar});

  bool get esEdicion => unidadAEditar != null;

  static Future<void> mostrar(
    BuildContext context, {
    UnidadMedida? unidadAEditar,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoUnidadMedida(unidadAEditar: unidadAEditar),
    );
  }

  @override
  ConsumerState<DialogoUnidadMedida> createState() =>
      _DialogoUnidadMedidaState();
}

class _DialogoUnidadMedidaState extends ConsumerState<DialogoUnidadMedida> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _abreviaturaCtrl;
  late final TextEditingController _descripcionCtrl;
  late String _tipoSeleccionado;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(
      text: widget.unidadAEditar?.nombre ?? '',
    );
    _abreviaturaCtrl = TextEditingController(
      text: widget.unidadAEditar?.abreviatura ?? '',
    );
    _descripcionCtrl = TextEditingController(
      text: widget.unidadAEditar?.descripcion ?? '',
    );
    _tipoSeleccionado = widget.unidadAEditar?.tipo ?? 'unidad';
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _abreviaturaCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final notifier = ref.read(unidadesMedidaProvider.notifier);
    String? error;

    if (widget.esEdicion) {
      error = await notifier.actualizar(
        id: widget.unidadAEditar!.id!,
        nombre: _nombreCtrl.text,
        abreviatura: _abreviaturaCtrl.text,
        tipo: _tipoSeleccionado,
        descripcion: _descripcionCtrl.text.isEmpty
            ? 'Sin descripción'
            : _descripcionCtrl.text,
      );
    } else {
      error = await notifier.crear(
        nombre: _nombreCtrl.text,
        abreviatura: _abreviaturaCtrl.text,
        tipo: _tipoSeleccionado,
        descripcion: _descripcionCtrl.text.isEmpty
            ? 'Sin descripción'
            : _descripcionCtrl.text,
      );
    }

    if (!mounted) return;
    setState(() => _guardando = false);

    if (error == null) {
      Navigator.of(context).pop();
      SnackBarMensaje.success(
        context,
        widget.esEdicion
            ? 'Unidad actualizada correctamente'
            : 'Unidad creada correctamente',
      );
    } else {
      SnackBarMensaje.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.esEdicion
                        ? 'Editar Unidad'
                        : 'Nueva Unidad de Medida',
                    style: const TextStyle(
                      color: ColoresApp.textDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: ColoresApp.textMedium),
                    style: IconButton.styleFrom(
                      backgroundColor: ColoresApp.bgContent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _etiqueta('Nombre'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nombreCtrl,
                          decoration: _deco('Ej: Kilogramo'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Campo requerido';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _etiqueta('Abreviatura'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _abreviaturaCtrl,
                          decoration: _deco('Ej: kg'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Campo requerido';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _etiqueta('Tipo'),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: ColoresApp.bgContent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ColoresApp.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _tipoSeleccionado,
                    isExpanded: true,
                    style: const TextStyle(
                      color: ColoresApp.textDark,
                      fontSize: 13.5,
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: ColoresApp.textMedium,
                    ),
                    items: UnidadMedida.tiposDisponibles
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                              t[0].toUpperCase() + t.substring(1),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _tipoSeleccionado = v ?? 'unidad'),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _etiqueta('Descripción (opcional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descripcionCtrl,
                maxLines: 2,
                decoration: _deco('Descripción adicional...'),
              ),
              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ColoresApp.textMedium,
                        side: const BorderSide(color: ColoresApp.border),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.esEdicion
                                  ? 'Guardar cambios'
                                  : 'Crear unidad',
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

  Widget _etiqueta(String texto) => Text(
        texto,
        style: const TextStyle(
          color: ColoresApp.textDark,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      );

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: ColoresApp.textLight, fontSize: 13.5),
        filled: true,
        fillColor: ColoresApp.bgContent,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ColoresApp.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ColoresApp.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ColoresApp.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ColoresApp.statusDebt),
        ),
      );
}
