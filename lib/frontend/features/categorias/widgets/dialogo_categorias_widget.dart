import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/temas/decoracion_inputs_widget.dart';

import '../../../../backend/features/categorias/modelo/categoria.dart';
import '../../../share/widgets/output/snack_bar_mensaje.dart';
import '../provider/categorias_provider.dart';

class DialogoCategoria extends ConsumerStatefulWidget {
  final Categoria? categoriaAEditar;

  const DialogoCategoria({super.key, this.categoriaAEditar});

  bool get esEdicion => categoriaAEditar != null;

  static Future<void> mostrar(
    BuildContext context, {
    Categoria? categoriaAEditar,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoCategoria(categoriaAEditar: categoriaAEditar),
    );
  }

  @override
  ConsumerState<DialogoCategoria> createState() => _DialogoCategoriaState();
}

class _DialogoCategoriaState extends ConsumerState<DialogoCategoria> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(
      text: widget.categoriaAEditar?.nombre ?? '',
    );
    _descripcionCtrl = TextEditingController(
      text: widget.categoriaAEditar?.descripcion ?? '',
    );
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final notifier = ref.read(categoriasProvider.notifier);
    String? error;

    if (widget.esEdicion) {
      error = await notifier.actualizar(
        id: widget.categoriaAEditar!.id!,
        nombre: _nombreCtrl.text,
        descripcion:
            _descripcionCtrl.text.isEmpty ? null : _descripcionCtrl.text,
      );
    } else {
      error = await notifier.crear(
        nombre: _nombreCtrl.text,
        descripcion:
            _descripcionCtrl.text.isEmpty ? null : _descripcionCtrl.text,
      );
    }

    if (!mounted) return;
    setState(() => _guardando = false);

    if (error == null) {
      Navigator.of(context).pop();
      SnackBarMensaje.success(
        context,
        widget.esEdicion
            ? 'Categoría actualizada correctamente'
            : 'Categoría creada correctamente',
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
        width: 480,
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
                    widget.esEdicion ? 'Editar Categoría' : 'Nueva Categoría',
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

              _etiquetaCampo('Nombre'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nombreCtrl,
                decoration: dialogInputDecoration('Ej: Filtros, Lubricantes...'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'El nombre es requerido';
                  }
                  if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _etiquetaCampo('Descripción (opcional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descripcionCtrl,
                maxLines: 2,
                decoration: dialogInputDecoration(
                  'Breve descripción de la categoría...',
                ),
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
                                  : 'Crear categoría',
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

  Widget _etiquetaCampo(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        color: ColoresApp.textDark,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
