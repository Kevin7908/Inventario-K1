import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/especializacion/modelo/especializacion.dart';
import '../../../../core/resultado.dart';
import '../../../share/share.dart';
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

  /// El «ya existe» que devolvió la última escritura. Se limpia en cuanto
  /// el usuario toca el campo: un error pegado a un texto que ya cambió
  /// dice algo que dejó de ser cierto.
  String? _errorNombre;

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

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    final notifier = ref.read(especializacionesProvider.notifier);
    final descripcion = _descripcionCtrl.text.trim();

    // El nombre repetido ya no se pregunta antes de escribir: lo decide el
    // repositorio dentro de la misma llamada, y vuelve como
    // `MotivoFallo.nombreDuplicado`. Preguntar primero dejaba un hueco entre
    // el `SELECT` y el `INSERT`, que es justo lo que el `UNIQUE` cierra.
    final resultado = widget.esEdicion
        ? await notifier.actualizar(
            id: widget.especializacionAEditar!.id,
            nombre: _nombreCtrl.text.trim(),
            descripcion: descripcion.isEmpty ? null : descripcion,
          )
        : await notifier.agregar(
            nombre: _nombreCtrl.text.trim(),
            descripcion: descripcion.isEmpty ? null : descripcion,
          );

    if (!mounted) return;

    switch (resultado) {
      case Fallo(motivo: MotivoFallo.nombreDuplicado, :final mensaje):
        // El conflicto es del campo, así que se señala en el campo y el
        // diálogo se queda abierto con lo que el usuario ya tecleó.
        setState(() {
          _errorNombre = mensaje;
          _guardando = false;
        });
        _formKey.currentState!.validate();
      case Fallo(:final mensaje):
        MensajeApp.error(context, mensaje);
        setState(() => _guardando = false);
      case Exito():
        Navigator.of(context).pop();
        MensajeApp.exito(
          context,
          widget.esEdicion
              ? 'Especialización actualizada correctamente.'
              : 'Especialización creada correctamente.',
        );
    }
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
                        alCambiar: _errorNombre == null
                            ? null
                            : (_) => setState(() => _errorNombre = null),
                        validador: (v) {
                          final texto = v?.trim() ?? '';
                          if (texto.isEmpty) {
                            return 'El nombre es obligatorio.';
                          }
                          if (texto.length < 2) return 'Mínimo 2 caracteres.';
                          if (texto.length > 120) {
                            return 'Máximo 120 caracteres.';
                          }
                          return _errorNombre;
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
