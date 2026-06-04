// frontend/features/tecnicos/widgets/dialogo_tecnico_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/especializacion/modelo/especializacion.dart';
import '../../../../backend/features/tecnicos/modelo/tecnico.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/input/app_searc_widget.dart';
import '../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../especializacion/provider/especializacion_provider.dart';
import '../../especializacion/widgets/dialogo_especializacion.dart';
import '../provider/tecnico_provider.dart';

class DialogoTecnico extends ConsumerStatefulWidget {
  const DialogoTecnico({super.key, this.tecnicoAEditar});

  final Tecnico? tecnicoAEditar;

  bool get esEdicion => tecnicoAEditar != null;

  static Future<void> mostrar(BuildContext context, {Tecnico? tecnicoAEditar}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoTecnico(tecnicoAEditar: tecnicoAEditar),
    );
  }

  @override
  ConsumerState<DialogoTecnico> createState() => _DialogoTecnicoState();
}

class _DialogoTecnicoState extends ConsumerState<DialogoTecnico> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombresCtrl;
  late final TextEditingController _apellidosCtrl;
  late final TextEditingController _cedulaCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _salarioCtrl;
  late bool _activo;

  // Notifier del AppSearch — el State es dueño del ciclo de vida.
  late final ValueNotifier<Especializacion?> _especializacionNotifier;

  bool _validandoCedula = false;
  String? _errorCedula;

  @override
  void initState() {
    super.initState();
    final t = widget.tecnicoAEditar;
    _nombresCtrl = TextEditingController(text: t?.nombres ?? '');
    _apellidosCtrl = TextEditingController(text: t?.apellidos ?? '');
    _cedulaCtrl = TextEditingController(text: t?.cedula ?? '');
    _telefonoCtrl = TextEditingController(text: t?.telefono ?? '');
    _emailCtrl = TextEditingController(text: t?.email ?? '');
    _salarioCtrl = TextEditingController(
      text: t?.salarioBase?.toStringAsFixed(0) ?? '',
    );
    _activo = t?.activo ?? true;

    // Pre-cargamos la especialización resuelta si ya viene en el modelo.
    _especializacionNotifier = ValueNotifier(null);
  }

  /// Cuando editamos y sólo tenemos el ID (sin objeto resuelto),
  /// lo buscamos en el provider ya cargado — sin roundtrip extra a la BD.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final t = widget.tecnicoAEditar;
    if (t != null &&
        t.especializacionId != null &&
        _especializacionNotifier.value == null) {
      final asyncLista = ref.read(especializacionesProvider);
      asyncLista.whenData((lista) {
        final encontrada = lista.cast<Especializacion?>().firstWhere(
          (e) => e?.id == t.especializacionId,
          orElse: () => null,
        );
        if (mounted && encontrada != null) {
          _especializacionNotifier.value = encontrada;
        }
      });
    }
  }

  @override
  void dispose() {
    _nombresCtrl.dispose();
    _apellidosCtrl.dispose();
    _cedulaCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _salarioCtrl.dispose();
    _especializacionNotifier.dispose();
    super.dispose();
  }

  // Validación asíncrona de cédula

  Future<void> _validarCedula(String cedula) async {
    if (cedula.trim().isEmpty) {
      setState(() => _errorCedula = null);
      return;
    }
    setState(() {
      _validandoCedula = true;
      _errorCedula = null;
    });
    final existe = await ref
        .read(repositorioTecnicoProvider)
        .existeCedula(cedula.trim(), excluirId: widget.tecnicoAEditar?.id);
    if (!mounted) return;
    setState(() {
      _validandoCedula = false;
      _errorCedula = existe ? 'Ya existe un técnico con esta cédula' : null;
    });
  }

  // Guardar

  Future<void> _guardar() async {
    await _validarCedula(_cedulaCtrl.text);
    if (_errorCedula != null) return;
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(tecnicosProvider.notifier);
    final cedula = _cedulaCtrl.text.trim().isEmpty
        ? null
        : _cedulaCtrl.text.trim();
    final salario = double.tryParse(_salarioCtrl.text.trim());
    final especId = _especializacionNotifier.value?.id; // FK que persiste

    String? error;

    if (widget.esEdicion) {
      error = await notifier.editar(
        id: widget.tecnicoAEditar!.id!,
        nombres: _nombresCtrl.text.trim(),
        apellidos: _apellidosCtrl.text.trim().isEmpty
            ? null
            : _apellidosCtrl.text.trim(),
        cedula: cedula,
        telefono: _telefonoCtrl.text.trim().isEmpty
            ? null
            : _telefonoCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        especializacionId: especId,
        salarioBase: salario,
        activo: _activo,
      );
    } else {
      error = await notifier.agregar(
        nombres: _nombresCtrl.text.trim(),
        apellidos: _apellidosCtrl.text.trim().isEmpty
            ? null
            : _apellidosCtrl.text.trim(),
        cedula: cedula,
        telefono: _telefonoCtrl.text.trim().isEmpty
            ? null
            : _telefonoCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        especializacionId: especId,
        salarioBase: salario,
        activo: _activo,
      );
    }

    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop();
      SnackBarMensaje.success(
        context,
        widget.esEdicion
            ? 'Técnico actualizado correctamente'
            : 'Técnico creado correctamente',
      );
    } else {
      SnackBarMensaje.error(context, error);
    }
  }

  // Build

  @override
  Widget build(BuildContext context) {
    final cargando = ref.watch(tecnicosProvider).isLoading;

    // Escuchamos el provider real de especializaciones.
    // Como es un AsyncNotifier con Stream de Drift, se actualiza
    // automáticamente si se agrega una especialización desde el diálogo.
    final asyncEspec = ref.watch(especializacionesProvider);

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
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.esEdicion ? 'Editar Técnico' : 'Nuevo Técnico',
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
                      // Nombres + Apellidos
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _etiqueta('Nombres *'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _nombresCtrl,
                                  decoration: _inputDeco('Ej: Carlos Andrés'),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty)
                                      return 'Requerido';
                                    if (v.trim().length < 2)
                                      return 'Mínimo 2 caracteres';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _etiqueta('Apellidos'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _apellidosCtrl,
                                  decoration: _inputDeco('Ej: Méndez Ruiz'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Cédula
                      _etiqueta('Cédula'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _cedulaCtrl,
                        decoration: _inputDeco('Ej: 1020304050').copyWith(
                          errorText: _errorCedula,
                          suffixIcon: _validandoCedula
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: ColoresApp.primary,
                                    ),
                                  ),
                                )
                              : (_errorCedula == null &&
                                        _cedulaCtrl.text.isNotEmpty
                                    ? const Icon(
                                        Icons.check_circle_outline,
                                        color: ColoresApp.statusPaid,
                                        size: 18,
                                      )
                                    : null),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: _validarCedula,
                      ),
                      const SizedBox(height: 14),

                      // Especialización — AppSearch
                      _etiqueta('Especialización'),
                      const SizedBox(height: 6),
                      asyncEspec.when(
                        loading: () => const _CampoSkeleton(),
                        error: (e, _) => _CampoError(
                          onReintentar: () =>
                              ref.invalidate(especializacionesProvider),
                        ),
                        data: (especializaciones) => AppSearch<Especializacion>(
                          notifier: _especializacionNotifier,
                          items: especializaciones,
                          labelBuilder: (e) => e.nombre,
                          hint: 'Seleccionar especialización',
                          // Al presionar "Agregar nuevo" abre el diálogo
                          // de especialización. Como el notifier usa Stream
                          // de Drift, la lista del AppSearch se actualiza
                          // sola en cuanto se guarda la nueva especialización.
                          onAgregar: () =>
                              _abrirDialogoEspecializacion(context),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Teléfono + Email
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _etiqueta('Teléfono'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _telefonoCtrl,
                                  decoration: _inputDeco('Ej: 3001234567'),
                                  keyboardType: TextInputType.phone,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _etiqueta('Salario base (opcional)'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _salarioCtrl,
                                  decoration: _inputDeco('Ej: 1800000'),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: false,
                                      ),
                                  validator: (v) {
                                    if (v != null && v.isNotEmpty) {
                                      if (double.tryParse(v) == null) {
                                        return 'Ingresa un número válido';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Salario base
                      _etiqueta('Correo electrónico'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: _inputDeco('Ej: tecnico@taller.com'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v != null && v.isNotEmpty && !v.contains('@')) {
                            return 'Correo inválido';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          _etiqueta('Estado'),
                          const Spacer(),
                          Switch(
                            value: _activo,
                            onChanged: (v) => setState(() => _activo = v),
                            activeThumbColor: ColoresApp.statusPaid,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _activo ? 'Activo' : 'Inactivo',
                            style: TextStyle(
                              color: _activo
                                  ? ColoresApp.statusPaid
                                  : ColoresApp.textLight,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              child: Row(
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
                      onPressed: (cargando || _validandoCedula)
                          ? null
                          : _guardar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColoresApp.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: (cargando || _validandoCedula)
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
                                  : 'Crear técnico',
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

  void _abrirDialogoEspecializacion(BuildContext context) {
    DialogoEspecializacion.mostrar(context);
  }

  Widget _etiqueta(String texto) {
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
}

/// Mismo alto que el campo real — evita layout jump mientras carga.
class _CampoSkeleton extends StatelessWidget {
  const _CampoSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresApp.border),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: ColoresApp.primary,
        ),
      ),
    );
  }
}

class _CampoError extends StatelessWidget {
  const _CampoError({required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: ColoresApp.statusDebtBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresApp.statusDebt.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: ColoresApp.statusDebt,
            size: 16,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Error al cargar especializaciones',
              style: TextStyle(color: ColoresApp.statusDebt, fontSize: 12.5),
            ),
          ),
          TextButton(
            onPressed: onReintentar,
            style: TextButton.styleFrom(
              foregroundColor: ColoresApp.statusDebt,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Reintentar', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}
