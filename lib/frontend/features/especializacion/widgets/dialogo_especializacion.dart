// frontend/features/especializaciones/widgets/dialogo_especializacion_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/frontend/features/especializacion/provider/especializacion_provider.dart';

import '../../../../backend/features/especializacion/modelo/especializacion.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/output/snack_bar_mensaje.dart';

class DialogoEspecializacion extends ConsumerStatefulWidget {
  const DialogoEspecializacion({
    super.key,
    this.especializacionAEditar,
  });

  final Especializacion? especializacionAEditar;

  bool get esEdicion => especializacionAEditar != null;

  // Factory helper
  static Future<void> mostrar(
    BuildContext context, {
    Especializacion? especializacionAEditar,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoEspecializacion(
        especializacionAEditar: especializacionAEditar,
      ),
    );
  }

  @override
  ConsumerState<DialogoEspecializacion> createState() =>
      _DialogoEspecializacionState();
}

class _DialogoEspecializacionState
    extends ConsumerState<DialogoEspecializacion> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final e = widget.especializacionAEditar;
    _nombreCtrl = TextEditingController(text: e?.nombre ?? '');
    _descripcionCtrl = TextEditingController(text: e?.descripcion ?? '');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  // Validación asíncrona de nombre único
  Future<String?> _validarNombreUnico(String nombre) async {
    if (nombre.trim().length < 2) return null; // ya capturado por validación síncrona

    final repo = ref.read(repositorioEspecializacionProvider);
    final existe = await repo.existeNombre(
      nombre.trim(),
      ignorarId: widget.especializacionAEditar?.id,
    );
    if (existe) return 'Ya existe una especialización con ese nombre.';
    return null;
  }

  // Guardar
  Future<void> _guardar() async {
    // 1. Validación síncrona del formulario
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    // 2. Validación asíncrona de unicidad antes de llamar al repositorio
    final errorUnicidad = await _validarNombreUnico(_nombreCtrl.text);
    if (errorUnicidad != null) {
      if (!mounted) return;
      SnackBarMensaje.error(context, errorUnicidad);
      setState(() => _guardando = false);
      return;
    }

    // 3. Persistencia a través del Notifier
    final notifier = ref.read(especializacionesProvider.notifier);
    final String? error;

    if (widget.esEdicion) {
      error = await notifier.actualizar(
        id: widget.especializacionAEditar!.id,
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim().isEmpty
            ? null
            : _descripcionCtrl.text.trim(),
      );
    } else {
      error = await notifier.agregar(
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim().isEmpty
            ? null
            : _descripcionCtrl.text.trim(),
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
        widget.esEdicion
            ? 'Especialización actualizada correctamente.'
            : 'Especialización creada correctamente.',
      );
    }
  }

  // UI
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 460,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Encabezado
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ColoresApp.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.build_outlined,
                      color: ColoresApp.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.esEdicion
                          ? 'Editar Especialización'
                          : 'Nueva Especialización',
                      style: const TextStyle(
                        color: ColoresApp.textDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _guardando
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: ColoresApp.textMedium,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: ColoresApp.bgContent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Formulario scrollable
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre — obligatorio
                      _Etiqueta('Nombre *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nombreCtrl,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDeco(
                          'Ej: Motores, Eléctrico, Suspensión...',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'El nombre es obligatorio.';
                          }
                          if (v.trim().length < 2) {
                            return 'Mínimo 2 caracteres.';
                          }
                          if (v.trim().length > 120) {
                            return 'Máximo 120 caracteres.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Descripción — opcional
                      _Etiqueta('Descripción (opcional)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descripcionCtrl,
                        maxLines: 3,
                        decoration: _inputDeco(
                          'Describe el alcance de esta área técnica...',
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Una descripción breve ayuda al equipo a entender el área.',
                        style: TextStyle(
                          color: ColoresApp.textLight,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Botones fijos
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _guardando
                          ? null
                          : () => Navigator.of(context).pop(),
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
                                  : 'Crear especialización',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helpers de estilo
  Widget _Etiqueta(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        color: ColoresApp.textDark,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
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
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: ColoresApp.statusDebt, width: 1.5),
      ),
    );
  }
}