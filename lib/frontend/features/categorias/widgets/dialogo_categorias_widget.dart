import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/share/temas/decoracion_inputs_widget.dart';
import 'package:provider/provider.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import '../../../../backend/features/categorias/modelo/categoria.dart';
import '../../../share/widgets/output/snack_bar_mensaje.dart';
import '../view_model/categorias_view_model.dart';

class DialogoCategoria extends StatefulWidget {
  final Categoria? categoriaAEditar;
  final CategoriasViewModel viewModel;

  const DialogoCategoria({
    super.key,
    this.categoriaAEditar,
    required this.viewModel,
  });

  bool get esEdicion => categoriaAEditar != null;

  static Future<void> mostrar(
    BuildContext context, {
    required CategoriasViewModel viewModel, // Recibirlo por parámetro
    Categoria? categoriaAEditar,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider<CategoriasViewModel>.value(
        value: viewModel, // Inyectarlo en la nueva ruta del diálogo
        child: DialogoCategoria(
          viewModel: viewModel,
          categoriaAEditar: categoriaAEditar,
        ),
      ),
    );
  }

  @override
  State<DialogoCategoria> createState() => _DialogoCategoriaState();
} // Fin DialogoCategoria

class _DialogoCategoriaState extends State<DialogoCategoria> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;
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
  ];

  static const List<Map<String, dynamic>> _iconosDisponibles = [
    {'nombre': 'category', 'icono': Icons.category_outlined},
    {'nombre': 'oil_barrel', 'icono': Icons.oil_barrel_outlined},
    {'nombre': 'settings', 'icono': Icons.settings_outlined},
    {
      'nombre': 'electrical_services',
      'icono': Icons.electrical_services_outlined,
    },
    {'nombre': 'tire_repair', 'icono': Icons.tire_repair_outlined},
    {'nombre': 'link', 'icono': Icons.link_outlined},
    {'nombre': 'car_repair', 'icono': Icons.car_repair_outlined},
    {'nombre': 'construction', 'icono': Icons.construction_outlined},
    {'nombre': 'inventory', 'icono': Icons.inventory_2_outlined},
    {'nombre': 'build', 'icono': Icons.build_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(
      text: widget.categoriaAEditar?.nombre ?? '',
    );
    _descripcionCtrl = TextEditingController(
      text: widget.categoriaAEditar?.descripcion ?? '',
    );
    _colorSeleccionado = widget.categoriaAEditar?.colorHex ?? '#3B82F6';
    _iconoSeleccionado = widget.categoriaAEditar?.icono ?? 'category';
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
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

    // El ViewModel ya está en el árbol gracias a ChangeNotifierProvider.value
    // en la vista padre, por lo que context.read funciona correctamente.
    final vm = context.read<CategoriasViewModel>();
    bool exito;

    if (widget.esEdicion) {
      exito = await vm.actualizarCategoria(
        // Esos ! es para indicar que no es nulo
        id: widget.categoriaAEditar!.id!,
        nombre: _nombreCtrl.text,
        descripcion: _descripcionCtrl.text.isEmpty
            ? null
            : _descripcionCtrl.text,
        colorHex: _colorSeleccionado,
        icono: _iconoSeleccionado,
      );
    } else {
      exito = await vm.crearCategoria(
        nombre: _nombreCtrl.text,
        descripcion: _descripcionCtrl.text.isEmpty
            ? null
            : _descripcionCtrl.text,
        colorHex: _colorSeleccionado,
        icono: _iconoSeleccionado,
      );
    }
    // mounted es un booleano que indica si el widget sigue estando en pantalla.
    // false = el widget ya fue destruido (dispose()),para cosas asincronas
    if (!mounted) return;

    if (exito) {
      Navigator.of(context).pop();

      SnackBarMensaje.success(
        context,
        widget.esEdicion
            ? 'Categoría actualizada correctamente'
            : 'Categoría creada correctamente',
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
        width: 480,
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
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
                decoration: DecoracionInputsWidget.basica(hint: 'Ej: Filtros, Lubricantes...'),
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
                decoration: DecoracionInputsWidget.basica(hint: 'Breve descripción de la categoría...',),
              ),
              const SizedBox(height: 16),

              // Selector de color
              _etiquetaCampo('Color'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _coloresDisponibles.map((c) {
                  final color = _hexAColor(c['hex'] as String);
                  final seleccionado = _colorSeleccionado == c['hex'];
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _colorSeleccionado = c['hex'] as String),
                    child: Tooltip(
                      message: c['nombre'] as String,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          // border: Border.all(
                          //   color: seleccionado
                          //       ? ColoresApp.textDark
                          //       : Colors.transparent,
                          //   width: 2.5,
                          // ),
                          // boxShadow: seleccionado
                          //     ? [
                          //         BoxShadow(
                          //           color: color.withOpacity(0.4),
                          //           blurRadius: 8,
                          //         ),
                          //       ]
                          //     : null,
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
              _etiquetaCampo('Ícono'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _iconosDisponibles.map((i) {
                  final seleccionado = _iconoSeleccionado == i['nombre'];
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
              const SizedBox(height: 28),

              // Botones
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
                    child: Consumer<CategoriasViewModel>(
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
                                    : 'Crear categoría',
                              ),
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
