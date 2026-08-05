import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/categorias/modelo/categoria.dart';
import '../../../../core/resultado.dart';
import '../../../share2/share2.dart';
import '../provider/categorias_provider.dart';

/// Diálogo de creación y edición de una categoría.
///
/// Se abre con [DialogoCategoria.mostrar]. Si recibe [categoriaAEditar]
/// trabaja en modo edición; si no, crea una nueva.
///
/// Es diálogo y no página porque el formulario son dos campos: el patrón de
/// páginas completas de Productos existe por el tamaño de aquel formulario.
class DialogoCategoria extends ConsumerStatefulWidget {
  const DialogoCategoria({super.key, this.categoriaAEditar});

  final Categoria? categoriaAEditar;

  bool get esEdicion => categoriaAEditar != null;

  static Future<void> mostrar(
    BuildContext context, {
    Categoria? categoriaAEditar,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoCategoria(categoriaAEditar: categoriaAEditar),
    );
  }

  @override
  ConsumerState<DialogoCategoria> createState() => _DialogoCategoriaState();
}

class _DialogoCategoriaState extends ConsumerState<DialogoCategoria> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final c = widget.categoriaAEditar;
    _nombreCtrl = TextEditingController(text: c?.nombre ?? '');
    _descripcionCtrl = TextEditingController(text: c?.descripcion ?? '');
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
        backgroundColor: esError
            ? ColoresApp.statusDanger
            : ColoresApp.statusSuccess,
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    final notifier = ref.read(categoriasProvider.notifier);
    final descripcion = _descripcionCtrl.text.trim();
    final Resultado resultado;

    if (widget.esEdicion) {
      resultado = await notifier.actualizar(
        id: widget.categoriaAEditar!.id!,
        nombre: _nombreCtrl.text.trim(),
        descripcion: descripcion.isEmpty ? null : descripcion,
      );
    } else {
      resultado = await notifier.crear(
        nombre: _nombreCtrl.text.trim(),
        descripcion: descripcion.isEmpty ? null : descripcion,
      );
    }

    if (!mounted) return;

    if (resultado case Fallo(:final mensaje)) {
      _mostrarMensaje(mensaje, esError: true);
      setState(() => _guardando = false);
      return;
    }

    Navigator.of(context).pop();
    _mostrarMensaje(
      widget.esEdicion
          ? 'Categoría actualizada correctamente.'
          : 'Categoría creada correctamente.',
      esError: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AtajosFormulario(
      alGuardar: _guardando ? null : _guardar,
      alCancelar: _guardando ? null : () => Navigator.of(context).pop(),
      child: Dialog(
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
                    const MarcadorIdentidad(
                      icono: Icons.layers_outlined,
                      lado: 42,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        widget.esEdicion
                            ? 'Editar categoría'
                            : 'Nueva categoría',
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
                          placeholder: 'Ej: Frenos, Motor, Lubricantes...',
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
                              'Qué tipo de repuestos agrupa esta categoría...',
                          lineas: 3,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Al renombrar una categoría se regenera el SKU de sus '
                          'productos.',
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
                      onPressed: _guardando
                          ? null
                          : () => Navigator.of(context).pop(),
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
                          : 'Crear categoría',
                      icono: Icons.check,
                      alPresionar: _guardando ? null : _guardar,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
