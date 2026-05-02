import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../share/temas/colores_app.dart';

class SelectorImagenWidget extends StatefulWidget {
  const SelectorImagenWidget({
    super.key,
    this.rutaActual,
    required this.onRutaSeleccionada,
    this.enabled = true,
  });

  final String? rutaActual;
  final ValueChanged<String?> onRutaSeleccionada;
  final bool enabled;

  @override
  State<SelectorImagenWidget> createState() => _SelectorImagenWidgetState();
}

class _SelectorImagenWidgetState extends State<SelectorImagenWidget> {
  // ValueNotifier para el estado de carga del picker — granular, no
  // reconstruye el widget padre que contiene el formulario completo.
  final ValueNotifier<bool> _cargando = ValueNotifier(false);

  @override
  void dispose() {
    _cargando.dispose();
    super.dispose();
  }

  Future<void> _abrirExplorador() async {
    if (_cargando.value) return; // guard contra doble-tap

    _cargando.value = true;

    try {
      // `FilePicker.platform` es el singleton estable en todas las versiones >= 5.
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif', 'avif'],
        allowMultiple: false,
        withData: false,
        withReadStream: false,
      );

      if (resultado == null || resultado.files.isEmpty) return;

      final file = resultado.files.single;

      // Verificación explícita de null: en Web path es nulo.
      if (file.path == null) {
        debugPrint(
          '[SelectorImagen] path es nulo. En Web usa withData: true y file.bytes.',
        );
        return;
      }

      widget.onRutaSeleccionada(file.path);
    } catch (e) {
      debugPrint('[SelectorImagen] Error al seleccionar archivo: $e');
    } finally {
      // Siempre restaurar el estado, incluso si hay excepción.
      if (mounted) _cargando.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tieneRuta =
        widget.rutaActual != null && widget.rutaActual!.isNotEmpty;
    final nombreArchivo = tieneRuta
        ? widget.rutaActual!.split(RegExp(r'[/\\]')).last
        : 'Ninguna imagen seleccionada';

    return Row(
      children: [
        // Botón: usa ValueListenableBuilder para mostrar spinner solo
        // durante la carga sin reconstruir el Row entero.
        ValueListenableBuilder<bool>(
          valueListenable: _cargando,
          builder: (_, cargando, _) => OutlinedButton.icon(
            onPressed: (widget.enabled && !cargando) ? _abrirExplorador : null,
            icon: cargando
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ColoresApp.primary,
                    ),
                  )
                : const Icon(Icons.image_outlined, size: 16),
            label: Text(cargando ? 'Abriendo...' : 'Elegir imagen'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ColoresApp.textMedium,
              side: const BorderSide(color: ColoresApp.border),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Campo de nombre del archivo seleccionado
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: ColoresApp.bgContent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ColoresApp.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    nombreArchivo,
                    style: TextStyle(
                      color: tieneRuta
                          ? ColoresApp.textDark
                          : ColoresApp.textLight,
                      fontSize: 12.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (tieneRuta)
                  GestureDetector(
                    onTap: widget.enabled
                        ? () => widget.onRutaSeleccionada(null)
                        : null,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.close,
                        size: 15,
                        color: ColoresApp.textLight,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}