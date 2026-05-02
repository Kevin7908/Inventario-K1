// frontend/features/proveedores/widgets/dialogo_proveedor_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import '../../../../backend/features/proveedores/modelo/proveedor.dart';
import '../../../share/widgets/output/snack_bar_mensaje.dart';
import '../view_model/proveedores_view_model.dart';

class DialogoProveedor extends StatefulWidget {
  final Proveedor? proveedorAEditar;
  final ProveedoresViewModel viewModel;

  const DialogoProveedor({
    super.key,
    this.proveedorAEditar,
    required this.viewModel,
  });

  bool get esEdicion => proveedorAEditar != null;

  static Future<void> mostrar(
    BuildContext context, {
    required ProveedoresViewModel viewModel,
    Proveedor? proveedorAEditar,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider<ProveedoresViewModel>.value(
        value: viewModel,
        child: DialogoProveedor(
          viewModel: viewModel,
          proveedorAEditar: proveedorAEditar,
        ),
      ),
    );
  }

  @override
  State<DialogoProveedor> createState() => _DialogoProveedorState();
}

class _DialogoProveedorState extends State<DialogoProveedor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _nitCtrl;
  late final TextEditingController _contactoCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _ciudadCtrl;
  late final TextEditingController _notasCtrl;
  late bool _activo;
  late String _colorSeleccionado;
  late String _iconoSeleccionado;

  static const List<Map<String, dynamic>> _coloresDisponibles = [
    {'hex': '#3B82F6', 'nombre': 'Azul'},
    {'hex': '#10B981', 'nombre': 'Verde'},
    {'hex': '#EF4444', 'nombre': 'Rojo'},
    {'hex': '#F59E0B', 'nombre': 'Amarillo'},
    {'hex': '#8B5CF6', 'nombre': 'Morado'},
    {'hex': '#F97316', 'nombre': 'Naranja'},
    {'hex': '#14B8A6', 'nombre': 'Teal'},
    {'hex': '#EC4899', 'nombre': 'Rosa'},
    {'hex': '#6366F1', 'nombre': 'Índigo'},
    {'hex': '#64748B', 'nombre': 'Gris'},
  ];

  static const List<Map<String, dynamic>> _iconosDisponibles = [
    {'nombre': 'store', 'icono': Icons.store_outlined},
    {'nombre': 'local_shipping', 'icono': Icons.local_shipping_outlined},
    {'nombre': 'factory', 'icono': Icons.factory_outlined},
    {'nombre': 'handshake', 'icono': Icons.handshake_outlined},
    {'nombre': 'inventory', 'icono': Icons.inventory_2_outlined},
    {'nombre': 'build', 'icono': Icons.build_outlined},
    {'nombre': 'oil_barrel', 'icono': Icons.oil_barrel_outlined},
    {'nombre': 'settings', 'icono': Icons.settings_outlined},
    {
      'nombre': 'electrical_services',
      'icono': Icons.electrical_services_outlined,
    },
    {'nombre': 'construction', 'icono': Icons.construction_outlined},
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.proveedorAEditar;
    _nombreCtrl = TextEditingController(text: p?.nombre ?? '');
    _nitCtrl = TextEditingController(text: p?.nitCedula ?? '');
    _contactoCtrl = TextEditingController(text: p?.contacto ?? '');
    _telefonoCtrl = TextEditingController(text: p?.telefono ?? '');
    _emailCtrl = TextEditingController(text: p?.email ?? '');
    _direccionCtrl = TextEditingController(text: p?.direccion ?? '');
    _ciudadCtrl = TextEditingController(text: p?.ciudad ?? '');
    _notasCtrl = TextEditingController(text: p?.notas ?? '');
    _activo = p?.activo ?? true;
    _colorSeleccionado = p?.colorHex ?? '#3B82F6';
    _iconoSeleccionado = p?.icono ?? 'store';
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _nitCtrl.dispose();
    _contactoCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _direccionCtrl.dispose();
    _ciudadCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Color _hexAColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return ColoresApp.primary;
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<ProveedoresViewModel>();
    bool exito;

    if (widget.esEdicion) {
      exito = await vm.actualizarProveedor(
        id: widget.proveedorAEditar!.id!,
        nombre: _nombreCtrl.text,
        nitCedula: _nitCtrl.text.isEmpty ? null : _nitCtrl.text,
        contacto: _contactoCtrl.text.isEmpty ? null : _contactoCtrl.text,
        telefono: _telefonoCtrl.text.isEmpty ? null : _telefonoCtrl.text,
        email: _emailCtrl.text.isEmpty ? null : _emailCtrl.text,
        direccion: _direccionCtrl.text.isEmpty ? null : _direccionCtrl.text,
        ciudad: _ciudadCtrl.text.isEmpty ? null : _ciudadCtrl.text,
        notas: _notasCtrl.text.isEmpty ? null : _notasCtrl.text,
        activo: _activo,
        colorHex: _colorSeleccionado,
        icono: _iconoSeleccionado,
      );
    } else {
      exito = await vm.crearProveedor(
        nombre: _nombreCtrl.text,
        nitCedula: _nitCtrl.text.isEmpty ? null : _nitCtrl.text,
        contacto: _contactoCtrl.text.isEmpty ? null : _contactoCtrl.text,
        telefono: _telefonoCtrl.text.isEmpty ? null : _telefonoCtrl.text,
        email: _emailCtrl.text.isEmpty ? null : _emailCtrl.text,
        direccion: _direccionCtrl.text.isEmpty ? null : _direccionCtrl.text,
        ciudad: _ciudadCtrl.text.isEmpty ? null : _ciudadCtrl.text,
        notas: _notasCtrl.text.isEmpty ? null : _notasCtrl.text,
        activo: _activo,
        colorHex: _colorSeleccionado,
        icono: _iconoSeleccionado,
      );
    }

    if (!mounted) return;

    if (exito) {
      Navigator.of(context).pop();
      SnackBarMensaje.success(
        context,
        widget.esEdicion
            ? 'Proveedor actualizado correctamente'
            : 'Proveedor creado correctamente',
      );
    } else if (vm.mensajeError != null) {
      SnackBarMensaje.error(context, vm.mensajeError!);
      vm.limpiarError();
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
            // ── Encabezado ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.esEdicion ? 'Editar Proveedor' : 'Nuevo Proveedor',
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

            // ── Formulario scrollable ─────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre (obligatorio)
                      _etiqueta('Nombre *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nombreCtrl,
                        decoration: _inputDeco(
                          'Ej: Distribuidora Moto Parts SAS',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'El nombre es requerido';
                          }
                          if (v.trim().length < 2) {
                            return 'Mínimo 2 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // NIT / Cédula
                      _etiqueta('NIT / Cédula'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nitCtrl,
                        decoration: _inputDeco('Ej: 900.123.456-7'),
                      ),
                      const SizedBox(height: 14),

                      // Contacto + Teléfono (en fila)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _etiqueta('Persona de contacto'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _contactoCtrl,
                                  decoration: _inputDeco('Ej: Carlos Méndez'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
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
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Email
                      _etiqueta('Correo electrónico'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: _inputDeco('Ej: ventas@proveedor.com'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),

                      // Dirección + Ciudad (en fila)
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
                                  decoration: _inputDeco('Ej: Bogotá'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Notas
                      _etiqueta('Notas (opcional)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notasCtrl,
                        maxLines: 2,
                        decoration: _inputDeco(
                          'Observaciones, condiciones de pago, etc.',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Estado activo
                      Row(
                        children: [
                          _etiqueta('Estado'),
                          const Spacer(),
                          Switch(
                            value: _activo,
                            onChanged: (v) => setState(() => _activo = v),
                            activeColor: const Color(0xFF10B981),
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
                      const SizedBox(height: 16),

                      // Selector de color
                      _etiqueta('Color'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _coloresDisponibles.map((c) {
                          final color = _hexAColor(c['hex'] as String);
                          final seleccionado = _colorSeleccionado == c['hex'];
                          return GestureDetector(
                            onTap: () => setState(
                              () => _colorSeleccionado = c['hex'] as String,
                            ),
                            child: Tooltip(
                              message: c['nombre'] as String,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                                child: seleccionado
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      )
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Selector de ícono
                      _etiqueta('Ícono'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _iconosDisponibles.map((i) {
                          final seleccionado =
                              _iconoSeleccionado == i['nombre'];
                          final colorActual = _hexAColor(_colorSeleccionado);
                          return GestureDetector(
                            onTap: () => setState(
                              () => _iconoSeleccionado = i['nombre'] as String,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: seleccionado
                                    ? colorActual.withOpacity(0.1)
                                    : ColoresApp.bgContent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: seleccionado
                                      ? colorActual.withOpacity(0.4)
                                      : ColoresApp.border,
                                ),
                              ),
                              child: Icon(
                                i['icono'] as IconData,
                                size: 20,
                                color: seleccionado
                                    ? colorActual
                                    : ColoresApp.textMedium,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Botones fijos en la parte inferior ───────────────────────
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
                    child: Consumer<ProveedoresViewModel>(
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
                                    : 'Crear proveedor',
                              ),
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
