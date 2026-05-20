import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/ventas/servicios/modelo/servicio.dart';
import '../../../../share/temas/colores_app.dart';
import '../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../provider/servicios_provider.dart';

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
  late bool _activo;

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final s = widget.servicioAEditar;
    _nombreCtrl = TextEditingController(text: s?.nombre ?? '');
    _descripcionCtrl = TextEditingController(text: s?.descripcion ?? '');
    _activo = s?.activo ?? true;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  // Validacion asincrona
  Future<String?> _validarNombreUnico(String nombre) async {
    if (nombre.trim().length < 2) return null; // la sincrona ya lo captura
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
      SnackBarMensaje.error(context, errorUnicidad);
      setState(() => _guardando = false);
      return;
    }

    final notifier = ref.read(serviciosProvider.notifier);
    final String? error;

    if (widget.esEdicion) {
      error = await notifier.actualizar(
        id: widget.servicioAEditar!.id,
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim().isEmpty
            ? null
            : _descripcionCtrl.text.trim(),
        activo: _activo,
      );
    } else {
      error = await notifier.agregar(
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim().isEmpty
            ? null
            : _descripcionCtrl.text.trim(),
        activo: _activo,
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
            ? 'Servicio actualizado correctamente.'
            : 'Servicio creado correctamente.',
      );
    }
  }

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
                      Icons.home_repair_service_outlined,
                      color: ColoresApp.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.esEdicion ? 'Editar Servicio' : 'Nuevo Servicio',
                      style: const TextStyle(
                        color: ColoresApp.textDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _guardando ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded,
                        color: ColoresApp.textMedium),
                    style: IconButton.styleFrom(
                      backgroundColor: ColoresApp.bgContent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
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
                      // Nombre
                      _Etiqueta('Nombre *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nombreCtrl,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDeco(
                            'Ej: Cambio de aceite, Sincronizacion...'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'El nombre es obligatorio.';
                          }
                          if (v.trim().length < 2) return 'Minimo 2 caracteres.';
                          if (v.trim().length > 120) return 'Maximo 120 caracteres.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Descripcion
                      _Etiqueta('Descripcion (opcional)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descripcionCtrl,
                        maxLines: 3,
                        decoration: _inputDeco(
                            'Describe el alcance de este trabajo...'),
                      ),
                      const SizedBox(height: 18),

                      // Toggle activo
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Etiqueta('Estado'),
                                const SizedBox(height: 2),
                                Text(
                                  _activo
                                      ? 'Visible en el catalogo'
                                      : 'Oculto del catalogo',
                                  style: const TextStyle(
                                      color: ColoresApp.textLight,
                                      fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _activo,
                            onChanged: _guardando
                                ? null
                                : (v) => setState(() => _activo = v),
                            activeColor: ColoresApp.primary,
                            inactiveThumbColor: ColoresApp.textLight,
                            inactiveTrackColor: ColoresApp.border,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Botones 
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
                          : Text(widget.esEdicion
                              ? 'Guardar cambios'
                              : 'Crear servicio'),
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

  Widget _Etiqueta(String texto) {
    return Text(
      texto,
      style: const TextStyle(
          color: ColoresApp.textDark,
          fontSize: 13,
          fontWeight: FontWeight.w600),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
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
}