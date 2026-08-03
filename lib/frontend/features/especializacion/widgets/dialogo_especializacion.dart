import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/especializacion/modelo/especializacion.dart';
import '../../../share2/share2.dart';
import '../provider/especializacion_provider.dart';

/// Diálogo de creación y edición de una especialización.
///
/// Se abre con [DialogoEspecializacion.mostrar]. Si recibe
/// [especializacionAEditar] trabaja en modo edición; si no, crea una nueva.
class DialogoEspecializacion extends ConsumerStatefulWidget {
  const DialogoEspecializacion({
    super.key,
    this.especializacionAEditar,
  });

  final Especializacion? especializacionAEditar;

  bool get esEdicion => especializacionAEditar != null;

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

  void _mostrarMensaje(String texto, {required bool esError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          texto,
          style: TipografiaApp.sobrePrimario(TipografiaApp.cuerpo),
        ),
        backgroundColor:
            esError ? ColoresApp.statusDanger : ColoresApp.statusSuccess,
      ),
    );
  }

  /// Validación de nombre único contra el repositorio, antes de persistir.
  Future<String?> _validarNombreUnico(String nombre) async {
    if (nombre.trim().length < 2) return null;

    final repo = ref.read(repositorioEspecializacionProvider);
    final existe = await repo.existeNombre(
      nombre.trim(),
      ignorarId: widget.especializacionAEditar?.id,
    );
    if (existe) return 'Ya existe una especialización con ese nombre.';
    return null;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    final errorUnicidad = await _validarNombreUnico(_nombreCtrl.text);
    if (errorUnicidad != null) {
      if (!mounted) return;
      _mostrarMensaje(errorUnicidad, esError: true);
      setState(() => _guardando = false);
      return;
    }

    final notifier = ref.read(especializacionesProvider.notifier);
    final descripcion = _descripcionCtrl.text.trim();
    final String? error;

    if (widget.esEdicion) {
      error = await notifier.actualizar(
        id: widget.especializacionAEditar!.id,
        nombre: _nombreCtrl.text.trim(),
        descripcion: descripcion.isEmpty ? null : descripcion,
      );
    } else {
      error = await notifier.agregar(
        nombre: _nombreCtrl.text.trim(),
        descripcion: descripcion.isEmpty ? null : descripcion,
      );
    }

    if (!mounted) return;

    if (error != null) {
      _mostrarMensaje(error, esError: true);
      setState(() => _guardando = false);
      return;
    }

    Navigator.of(context).pop();
    _mostrarMensaje(
      widget.esEdicion
          ? 'Especialización actualizada correctamente.'
          : 'Especialización creada correctamente.',
      esError: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 460,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: ColoresApp.bgCard,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: ColoresApp.shadowMedium,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: ColoresApp.greenChipBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.build_outlined,
                      color: ColoresApp.goGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      widget.esEdicion
                          ? 'Editar especialización'
                          : 'Nueva especialización',
                      style: TipografiaApp.heading3,
                    ),
                  ),
                  BotonIcono(
                    icono: Icons.close_rounded,
                    tooltip: 'Cerrar',
                    alPresionar: _guardando
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 4),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CampoTexto(
                        etiqueta: 'Nombre *',
                        controlador: _nombreCtrl,
                        placeholder: 'Ej: Motor, Eléctrico, Suspensión...',
                        autofocus: true,
                        validador: (v) {
                          final texto = v?.trim() ?? '';
                          if (texto.isEmpty) {
                            return 'El nombre es obligatorio.';
                          }
                          if (texto.length < 2) return 'Mínimo 2 caracteres.';
                          if (texto.length > 120) {
                            return 'Máximo 120 caracteres.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      CampoTexto(
                        etiqueta: 'Descripción (opcional)',
                        controlador: _descripcionCtrl,
                        placeholder:
                            'Describe el alcance de esta área técnica...',
                        lineas: 3,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Una descripción breve ayuda al equipo a entender el área.',
                        style: TipografiaApp.caption.copyWith(
                          fontSize: 12,
                          color: ColoresApp.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _guardando ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancelar',
                      style: TipografiaApp.cuerpoMedium.copyWith(
                        color: ColoresApp.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  BotonPrimario(
                    etiqueta: _guardando
                        ? 'Guardando...'
                        : widget.esEdicion
                            ? 'Guardar cambios'
                            : 'Crear especialización',
                    icono: Icons.check,
                    alPresionar: _guardando ? null : _guardar,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
