import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../backend/features/motos/modelo/moto.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/input/app_searc_widget.dart';
import '../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../clientes/provider/cliente_provider.dart';
import '../../clientes/widget/dialogo_cliente_widget.dart';
import '../provider/motos_provider.dart';

class DialogoMoto extends ConsumerStatefulWidget {
  const DialogoMoto({super.key, this.moto});
  final Moto? moto;

  bool get esEdicion => moto != null;

  static Future<void> mostrar(BuildContext context, {Moto? moto}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoMoto(moto: moto),
    );
  }

  @override
  ConsumerState<DialogoMoto> createState() => _DialogoMotoState();
}

class _DialogoMotoState extends ConsumerState<DialogoMoto> {
  final _formKey = GlobalKey<FormState>();
  late final ValueNotifier<Cliente?> _clienteNotifier;

  late final TextEditingController _placaCtrl;
  late final TextEditingController _marcaCtrl;
  late final TextEditingController _modeloCtrl;
  late final TextEditingController _anioCtrl;
  late final TextEditingController _cilindrajeCtrl;
  late final TextEditingController _colorCtrl;
  late final TextEditingController _vinCtrl;
  late final TextEditingController _numeroMotorCtrl;
  late final TextEditingController _kilometrajeCtrl;
  late final TextEditingController _notasCtrl;
  late bool _activo;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final m = widget.moto;

    final clientesActuales =
        ref.read(clientesProvider).value?.clientes ?? [];
    final clienteInicial = m != null
        ? clientesActuales.where((c) => c.id == m.clienteId).firstOrNull
        : null;

    _clienteNotifier = ValueNotifier<Cliente?>(clienteInicial);
    _placaCtrl = TextEditingController(text: m?.placa ?? '');
    _marcaCtrl = TextEditingController(text: m?.marca ?? '');
    _modeloCtrl = TextEditingController(text: m?.modelo ?? '');
    _anioCtrl = TextEditingController(
      text: m?.anio != null ? m!.anio.toString() : '',
    );
    _cilindrajeCtrl = TextEditingController(
      text: m?.cilindraje != null ? m!.cilindraje.toString() : '',
    );
    _colorCtrl = TextEditingController(text: m?.color ?? '');
    _vinCtrl = TextEditingController(text: m?.vin ?? '');
    _numeroMotorCtrl = TextEditingController(text: m?.numeroMotor ?? '');
    _kilometrajeCtrl = TextEditingController(
      text: m != null && m.kilometrajeInicial > 0
          ? m.kilometrajeInicial.toString()
          : '',
    );
    _notasCtrl = TextEditingController(text: m?.notas ?? '');
    _activo = m?.activo ?? true;
  }

  @override
  void dispose() {
    _clienteNotifier.dispose();
    _placaCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _anioCtrl.dispose();
    _cilindrajeCtrl.dispose();
    _colorCtrl.dispose();
    _vinCtrl.dispose();
    _numeroMotorCtrl.dispose();
    _kilometrajeCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clienteNotifier.value == null) {
      SnackBarMensaje.error(context, 'Selecciona un cliente.');
      return;
    }
    setState(() => _guardando = true);

    final moto = Moto(
      id: widget.moto?.id ?? 0,
      clienteId: _clienteNotifier.value!.id,
      placa: _placaCtrl.text.trim().isEmpty ? null : _placaCtrl.text.trim(),
      marca: _marcaCtrl.text.trim(),
      modelo: _modeloCtrl.text.trim(),
      anio: _anioCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_anioCtrl.text.trim()),
      cilindraje: _cilindrajeCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_cilindrajeCtrl.text.trim()),
      color: _colorCtrl.text.trim().isEmpty ? null : _colorCtrl.text.trim(),
      vin: _vinCtrl.text.trim().isEmpty ? null : _vinCtrl.text.trim(),
      numeroMotor: _numeroMotorCtrl.text.trim().isEmpty
          ? null
          : _numeroMotorCtrl.text.trim(),
      kilometrajeInicial: int.tryParse(_kilometrajeCtrl.text.trim()) ?? 0,
      notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      activo: _activo,
      creadoEn: widget.moto?.creadoEn ?? DateTime.now(),
      actualizadoEn: DateTime.now(),
    );

    final notifier = ref.read(motosProvider.notifier);
    final String? error = widget.esEdicion
        ? await notifier.actualizar(moto)
        : await notifier.crear(moto);

    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop();
      SnackBarMensaje.success(
        context,
        widget.esEdicion
            ? 'Moto actualizada correctamente'
            : 'Moto creada correctamente',
      );
    } else {
      SnackBarMensaje.error(context, error);
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientes =
        ref.watch(clientesProvider).value?.clientes ?? const [];

    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 560,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
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
                    widget.esEdicion ? 'Editar Moto' : 'Nueva Moto',
                    style: const TextStyle(
                      color: ColoresApp.textDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: _guardando
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.close, color: ColoresApp.textMedium),
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
                      _etiqueta('Cliente *'),
                      const SizedBox(height: 6),
                      AppSearch<Cliente>(
                        notifier: _clienteNotifier,
                        items: clientes,
                        labelBuilder: (c) => c.nombreCompleto,
                        hint: 'Seleccionar cliente',
                        validator: (v) =>
                            v == null ? 'Selecciona un cliente' : null,
                        onAgregar: () => DialogoCliente.mostrar(context),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _etiqueta('Marca *'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _marcaCtrl,
                                  decoration: _inputDeco('Ej: Honda'),
                                  textCapitalization:
                                      TextCapitalization.words,
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                          ? 'La marca es requerida'
                                          : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _etiqueta('Modelo *'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _modeloCtrl,
                                  decoration: _inputDeco('Ej: CB 190R'),
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                          ? 'El modelo es requerido'
                                          : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _etiqueta('Placa'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _placaCtrl,
                        decoration: _inputDeco('Ej: ABC123'),
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9]')),
                          LengthLimitingTextInputFormatter(7),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _etiqueta('Año'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _anioCtrl,
                                  decoration: _inputDeco('Ej: 2022'),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(4),
                                  ],
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return null;
                                    }
                                    final anio = int.tryParse(v.trim());
                                    if (anio == null ||
                                        anio < 1900 ||
                                        anio > DateTime.now().year + 1) {
                                      return 'Año inválido';
                                    }
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
                                _etiqueta('Cilindraje (cc)'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _cilindrajeCtrl,
                                  decoration: _inputDeco('Ej: 190'),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
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
                                _etiqueta('Color'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _colorCtrl,
                                  decoration: _inputDeco('Ej: Rojo'),
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _etiqueta('Km iniciales'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _kilometrajeCtrl,
                                  decoration: _inputDeco('Ej: 15000'),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _etiqueta('VIN / Nº Chasis'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _vinCtrl,
                        decoration: _inputDeco('Ej: 9BWZZZ377VT004251'),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 14),
                      _etiqueta('Número de motor'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _numeroMotorCtrl,
                        decoration: _inputDeco('Ej: CB190E-1234567'),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 14),
                      _etiqueta('Notas (opcional)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notasCtrl,
                        maxLines: 2,
                        decoration: _inputDeco(
                          'Observaciones, detalles especiales, etc.',
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
                                  : 'Registrar moto',
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
