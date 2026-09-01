import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/motos/modelo/marca_moto.dart';
import '../../../../core/resultado.dart';
import '../../../share/share.dart';
import '../provider/marcas_provider.dart';

/// Alta y renombrado de una marca de moto.
///
/// Se abre con [DialogoMarcaMoto.mostrar]. Con [marca] trabaja en modo
/// edición; sin ella, crea una nueva.
class DialogoMarcaMoto extends ConsumerStatefulWidget {
  const DialogoMarcaMoto({super.key, this.marca});

  final MarcaMoto? marca;

  bool get esEdicion => marca != null;

  static Future<void> mostrar(BuildContext context, {MarcaMoto? marca}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoMarcaMoto(marca: marca),
    );
  }

  @override
  ConsumerState<DialogoMarcaMoto> createState() => _DialogoMarcaMotoState();
}

class _DialogoMarcaMotoState extends ConsumerState<DialogoMarcaMoto> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl =
      TextEditingController(text: widget.marca?.nombre ?? '');

  bool _guardando = false;

  /// El «ya existe» que devolvió la última escritura. Se limpia al teclear:
  /// un error pegado a un texto que ya cambió dice algo que dejó de ser
  /// cierto.
  String? _errorNombre;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final repo = ref.read(repositorioMarcasMotoProvider);
    final nombre = _nombreCtrl.text.trim();
    final resultado = widget.esEdicion
        ? await repo.renombrarMarca(widget.marca!.id, nombre)
        : await repo.crearMarca(nombre);

    if (!mounted) return;

    switch (resultado) {
      case Fallo(motivo: MotivoFallo.nombreDuplicado, :final mensaje):
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
          widget.esEdicion ? 'Marca actualizada.' : 'Marca creada.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AtajosFormulario(
      alGuardar: _guardando ? null : _guardar,
      alCancelar: _guardando ? null : () => Navigator.of(context).pop(),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 420,
          decoration: BoxDecoration(
            color: ColoresApp.bgCard,
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.esEdicion ? 'Editar marca' : 'Nueva marca',
                  style: TipografiaApp.heading3,
                ),
                const SizedBox(height: 20),
                CampoTexto(
                  etiqueta: 'Nombre *',
                  controlador: _nombreCtrl,
                  placeholder: 'Ej: Yamaha, Bajaj, Honda…',
                  autofocus: true,
                  alCambiar: _errorNombre == null
                      ? null
                      : (_) => setState(() => _errorNombre = null),
                  validador: (v) {
                    final texto = v?.trim() ?? '';
                    if (texto.isEmpty) return 'El nombre es obligatorio.';
                    return _errorNombre;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    BotonSecundario(
                      etiqueta: 'Cancelar',
                      alPresionar: _guardando
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    BotonPrimario(
                      etiqueta: 'Guardar',
                      alPresionar: _guardando ? null : _guardar,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
