import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import '../../../../backend/features/unidades_medida/modelo/unidad_medida.dart';
import '../view_model/unidad_medida_view_model.dart';

class DialogoUnidadMedida extends StatefulWidget {
  final UnidadMedida? unidadAEditar;
  final UnidadesMedidaViewModel viewModel;

  const DialogoUnidadMedida({
    super.key,
    this.unidadAEditar,
    required this.viewModel,
  });

  bool get esEdicion => unidadAEditar != null;

  static Future<void> mostrar(
    BuildContext context, {
    required UnidadesMedidaViewModel viewModel,
    UnidadMedida? unidadAEditar,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider<UnidadesMedidaViewModel>.value(
        value: viewModel, // Inyectarlo en la nueva ruta del diálogo
        child: DialogoUnidadMedida(
          viewModel: viewModel,
          unidadAEditar: unidadAEditar,
        ),
      ),
    );
  }

  @override
  State<DialogoUnidadMedida> createState() => _DialogoUnidadMedidaState();
}

class _DialogoUnidadMedidaState extends State<DialogoUnidadMedida> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _abreviaturaCtrl;
  late final TextEditingController _descripcionCtrl;
  late String _tipoSeleccionado;

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

    final vm = context.read<UnidadesMedidaViewModel>();
    bool exito;

    if (widget.esEdicion) {
      exito = await vm.actualizarUnidad(
        id: widget.unidadAEditar!.id!,
        nombre: _nombreCtrl.text,
        abreviatura: _abreviaturaCtrl.text,
        tipo: _tipoSeleccionado,
        descripcion: _descripcionCtrl.text.isEmpty
            ? "Sin descripción"
            : _descripcionCtrl.text,
      );
    } else {
      exito = await vm.crearUnidad(
        nombre: _nombreCtrl.text,
        abreviatura: _abreviaturaCtrl.text,
        tipo: _tipoSeleccionado,
        descripcion: _descripcionCtrl.text.isEmpty
            ? "Sin descripción"
            : _descripcionCtrl.text,
      );
    }

    if (!mounted) return;

    if (exito) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.esEdicion
                ? 'Unidad actualizada correctamente'
                : 'Unidad creada correctamente',
          ),
          backgroundColor: ColoresApp.statusPaid,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else if (vm.mensajeError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.mensajeError!),
          backgroundColor: ColoresApp.statusDebt,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      vm.limpiarError();
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
              // Encabezado
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
                  // Icono para cerrar el diálogo
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

              // Nombre y Abreviatura en fila
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

              // Tipo
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
                            child: Text(t[0].toUpperCase() + t.substring(1)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _tipoSeleccionado = v ?? 'unidad'),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Descripción
              _etiqueta('Descripción (opcional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descripcionCtrl,
                maxLines: 2,
                decoration: _deco('Descripción adicional...'),
              ),
              const SizedBox(height: 28),

              // Botones
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
                    child: Consumer<UnidadesMedidaViewModel>(
                      builder: (_, vm, __) => ElevatedButton(
                        onPressed: vm.estaCargando ? null : _guardar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColoresApp.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: vm.estaCargando
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
