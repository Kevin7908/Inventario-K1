import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/motos/modelo/marca_moto.dart';
import '../../../../core/resultado.dart';
import '../../../share/share.dart';
import '../provider/marcas_provider.dart';

/// Alta y edición de un modelo dentro de una marca.
///
/// El cilindraje vive aquí y no en cada moto: todas las Boxer CT100 son de
/// 100 cc.
class DialogoModeloMoto extends ConsumerStatefulWidget {
  const DialogoModeloMoto({super.key, required this.marca, this.modelo});

  final MarcaMoto marca;
  final ModeloMoto? modelo;

  bool get esEdicion => modelo != null;

  static Future<void> mostrar(
    BuildContext context, {
    required MarcaMoto marca,
    ModeloMoto? modelo,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoModeloMoto(marca: marca, modelo: modelo),
    );
  }

  @override
  ConsumerState<DialogoModeloMoto> createState() => _DialogoModeloMotoState();
}

class _DialogoModeloMotoState extends ConsumerState<DialogoModeloMoto> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl =
      TextEditingController(text: widget.modelo?.nombre ?? '');
  late final TextEditingController _cilindrajeCtrl = TextEditingController(
    text: widget.modelo?.cilindraje?.toString() ?? '',
  );

  bool _guardando = false;
  String? _errorNombre;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cilindrajeCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final repo = ref.read(repositorioMarcasMotoProvider);
    final nombre = _nombreCtrl.text.trim();
    final cilindraje = int.tryParse(_cilindrajeCtrl.text.trim());
    final resultado = widget.esEdicion
        ? await repo.actualizarModelo(
            id: widget.modelo!.id,
            nombre: nombre,
            cilindraje: cilindraje,
          )
        : await repo.crearModelo(
            marcaId: widget.marca.id,
            nombre: nombre,
            cilindraje: cilindraje,
          );

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
          widget.esEdicion ? 'Modelo actualizado.' : 'Modelo creado.',
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
          width: 460,
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
                  widget.esEdicion
                      ? 'Editar modelo de ${widget.marca.nombre}'
                      : 'Nuevo modelo de ${widget.marca.nombre}',
                  style: TipografiaApp.heading3,
                ),
                const SizedBox(height: 20),
                FilaCampos(
                  hijos: [
                    CampoTexto(
                      etiqueta: 'Nombre *',
                      controlador: _nombreCtrl,
                      placeholder: 'Ej: FZ 2.0, Boxer CT100…',
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
                    CampoTexto(
                      etiqueta: 'Cilindraje (cc)',
                      controlador: _cilindrajeCtrl,
                      placeholder: 'Ej: 150',
                      soloEnteros: true,
                      validador: (v) {
                        final texto = v?.trim() ?? '';
                        if (texto.isEmpty) return null;
                        final numero = int.tryParse(texto);
                        if (numero == null || numero <= 0) {
                          return 'Tiene que ser mayor que cero.';
                        }
                        return null;
                      },
                    ),
                  ],
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
