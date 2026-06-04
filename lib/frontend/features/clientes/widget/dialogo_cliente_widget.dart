import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/output/snack_bar_mensaje.dart';
import '../provider/cliente_provider.dart';

class DialogoCliente extends ConsumerStatefulWidget {
  const DialogoCliente({super.key, this.cliente});
  final Cliente? cliente;

  bool get esEdicion => cliente != null;

  static Future<void> mostrar(BuildContext context, {Cliente? cliente}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoCliente(cliente: cliente),
    );
  }

  @override
  ConsumerState<DialogoCliente> createState() => _DialogoClienteState();
}

class _DialogoClienteState extends ConsumerState<DialogoCliente> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombresCtrl;
  late final TextEditingController _apellidosCtrl;
  late final TextEditingController _cedulaCtrl;
  late final TextEditingController _fechaNacimientoCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _ciudadCtrl;
  late final TextEditingController _notasCtrl;
  late bool _activo;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final c = widget.cliente;
    _nombresCtrl         = TextEditingController(text: c?.nombres ?? '');
    _apellidosCtrl       = TextEditingController(text: c?.apellidos ?? '');
    _cedulaCtrl          = TextEditingController(text: c?.cedula ?? '');
    _fechaNacimientoCtrl = TextEditingController(text: c?.fechaNacimiento ?? '');
    _telefonoCtrl        = TextEditingController(text: c?.telefono ?? '');
    _emailCtrl           = TextEditingController(text: c?.email ?? '');
    _direccionCtrl       = TextEditingController(text: c?.direccion ?? '');
    _ciudadCtrl          = TextEditingController(text: c?.ciudad ?? '');
    _notasCtrl           = TextEditingController(text: c?.notas ?? '');
    _activo              = c?.activo ?? true;
  }

  @override
  void dispose() {
    _nombresCtrl.dispose();
    _apellidosCtrl.dispose();
    _cedulaCtrl.dispose();
    _fechaNacimientoCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _direccionCtrl.dispose();
    _ciudadCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final cliente = Cliente(
      id: widget.cliente?.id ?? 0,
      nombres: _nombresCtrl.text.trim(),
      apellidos: _apellidosCtrl.text.trim().isEmpty
          ? null
          : _apellidosCtrl.text.trim(),
      cedula:
          _cedulaCtrl.text.trim().isEmpty ? null : _cedulaCtrl.text.trim(),
      fechaNacimiento: _fechaNacimientoCtrl.text.trim().isEmpty
          ? null
          : _fechaNacimientoCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim().isEmpty
          ? null
          : _telefonoCtrl.text.trim(),
      email:
          _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      direccion: _direccionCtrl.text.trim().isEmpty
          ? null
          : _direccionCtrl.text.trim(),
      ciudad:
          _ciudadCtrl.text.trim().isEmpty ? null : _ciudadCtrl.text.trim(),
      notas:
          _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      activo: _activo,
    );

    final notifier = ref.read(clientesProvider.notifier);
    final String? error = widget.esEdicion
        ? await notifier.actualizar(cliente)
        : await notifier.crear(cliente);

    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop();
      SnackBarMensaje.success(
        context,
        widget.esEdicion
            ? 'Cliente actualizado correctamente'
            : 'Cliente creado correctamente',
      );
    } else {
      SnackBarMensaje.error(context, error);
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.esEdicion ? 'Editar Cliente' : 'Nuevo Cliente',
                    style: const TextStyle(
                      color: ColoresApp.textDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _guardando ? null : () => Navigator.of(context).pop(),
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
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _etiqueta('Nombres *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nombresCtrl,
                        decoration: _inputDeco('Ej: Juan Carlos'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'El nombre es requerido';
                          }
                          if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _etiqueta('Apellidos'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _apellidosCtrl,
                        decoration: _inputDeco('Ej: Ramírez Gómez'),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _etiqueta('Cédula'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _cedulaCtrl,
                                  decoration: _inputDeco('Ej: 1234567890'),
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _etiqueta('Fecha de nacimiento'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _fechaNacimientoCtrl,
                                  decoration: _inputDeco('YYYY-MM-DD'),
                                  keyboardType: TextInputType.datetime,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
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
                                _etiqueta('Correo electrónico'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _emailCtrl,
                                  decoration:
                                      _inputDeco('Ej: cliente@email.com'),
                                  keyboardType: TextInputType.emailAddress,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _etiqueta('Dirección'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _direccionCtrl,
                                  decoration: _inputDeco('Ej: Cra 15 # 80-45'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _etiqueta('Ciudad'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _ciudadCtrl,
                                  decoration: _inputDeco('Ej: Medellín'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _etiqueta('Notas (opcional)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notasCtrl,
                        maxLines: 2,
                        decoration: _inputDeco(
                          'Observaciones, preferencias, referencias, etc.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _etiqueta('Estado'),
                          const Spacer(),
                          Switch(
                            value: _activo,
                            onChanged: (v) => setState(() => _activo = v),
                            activeThumbColor: const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _activo ? 'Activo' : 'Inactivo',
                            style: TextStyle(
                              color: _activo
                                  ? const Color(0xFF10B981)
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
                                  : 'Crear cliente',
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

  Widget _etiqueta(String texto) => Text(
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
