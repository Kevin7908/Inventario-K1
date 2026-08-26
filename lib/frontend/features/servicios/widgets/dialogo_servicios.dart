import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/servicios/modelo/servicio.dart';
import '../../../share2/share2.dart';
import '../provider/servicios_provider.dart';
import '../../../../core/formato.dart';
import '../../../../core/validaciones.dart';

/// Diálogo de creación y edición de un servicio del taller.
///
/// Se abre con [DialogoServicio.mostrar]. Si recibe [servicioAEditar] trabaja
/// en modo edición; si no, crea uno nuevo.
class DialogoServicio extends ConsumerStatefulWidget {
  const DialogoServicio({super.key, this.servicioAEditar});

  final Servicio? servicioAEditar;

  bool get esEdicion => servicioAEditar != null;

  static Future<void> mostrar(
    BuildContext context, {
    Servicio? servicioAEditar,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoServicio(servicioAEditar: servicioAEditar),
    );
  }

  @override
  ConsumerState<DialogoServicio> createState() => _DialogoServicioState();
}

class _DialogoServicioState extends ConsumerState<DialogoServicio> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _precioCtrl;
  late bool _activo;

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final s = widget.servicioAEditar;
    _nombreCtrl = TextEditingController(text: s?.nombre ?? '');
    _descripcionCtrl = TextEditingController(text: s?.descripcion ?? '');
    // 0 es "sin definir": el campo se muestra vacío en vez de con un cero.
    _precioCtrl = TextEditingController(
      // Ya agrupado, para que abra igual que como se ve al teclear.
      text: (s?.precioSugerido ?? 0) == 0
          ? ''
          : agruparMiles(s!.precioSugerido),
    );
    _activo = s?.activo ?? true;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioCtrl.dispose();
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

    final repo = ref.read(repositorioServiciosProvider);
    final existe = await repo.existeNombre(
      nombre.trim(),
      ignorarId: widget.servicioAEditar?.id,
    );
    if (existe) return 'Ya existe un servicio con ese nombre.';
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

    final notifier = ref.read(serviciosProvider.notifier);
    final descripcion = _descripcionCtrl.text.trim();
    final precioSugerido = int.tryParse(normalizarDigitos(_precioCtrl.text)) ?? 0;
    final String? error;

    if (widget.esEdicion) {
      error = await notifier.actualizar(
        id: widget.servicioAEditar!.id,
        nombre: _nombreCtrl.text.trim(),
        descripcion: descripcion.isEmpty ? null : descripcion,
        precioSugerido: precioSugerido,
        activo: _activo,
      );
    } else {
      error = await notifier.agregar(
        nombre: _nombreCtrl.text.trim(),
        descripcion: descripcion.isEmpty ? null : descripcion,
        precioSugerido: precioSugerido,
        activo: _activo,
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
          ? 'Servicio actualizado correctamente.'
          : 'Servicio creado correctamente.',
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
                      Icons.home_repair_service_outlined,
                      color: ColoresApp.goGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      widget.esEdicion ? 'Editar servicio' : 'Nuevo servicio',
                      style: TipografiaApp.heading3,
                    ),
                  ),
                  BotonIcono(
                    icono: Icons.close_rounded,
                    tooltip: 'Cerrar',
                    alPresionar:
                        _guardando ? null : () => Navigator.of(context).pop(),
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
                        placeholder: 'Ej: Cambio de aceite, Sincronización...',
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
                        placeholder: 'Describe el alcance de este trabajo...',
                        lineas: 3,
                      ),
                      const SizedBox(height: 18),
                      CampoTexto(
                        etiqueta: 'Precio sugerido (opcional)',
                        controlador: _precioCtrl,
                        placeholder: '0',
                        comoPrecio: true,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Precarga el precio al cotizar y al abrir una tarea de '
                        'orden. Se puede ajustar en cada trabajo sin cambiar '
                        'este valor.',
                        style: TipografiaApp.caption,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Estado',
                                  style: TipografiaApp.etiquetaCampo,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _activo
                                      ? 'Visible en el catálogo'
                                      : 'Oculto del catálogo',
                                  style: TipografiaApp.caption.copyWith(
                                    fontSize: 12,
                                    color: ColoresApp.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _activo,
                            onChanged: _guardando
                                ? null
                                : (v) => setState(() => _activo = v),
                            activeThumbColor: ColoresApp.goGreen,
                            inactiveThumbColor: ColoresApp.textDisabled,
                            inactiveTrackColor: ColoresApp.border,
                          ),
                        ],
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
                            : 'Crear servicio',
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
