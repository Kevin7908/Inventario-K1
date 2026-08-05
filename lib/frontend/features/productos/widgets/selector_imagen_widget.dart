import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../share2/share2.dart';

/// Zona de carga de la imagen del producto.
///
/// Mientras no hay imagen muestra el área punteada del diseño ("haz clic para
/// subir"); una vez elegida, la reemplaza por la vista previa con el nombre del
/// archivo y las acciones de cambiar o quitar.
///
/// Vive en el módulo y no en `share2` porque depende de `file_picker` y del
/// sistema de archivos, y share2 no admite dependencias externas.
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
  bool _cargando = false;

  Future<void> _abrirExplorador() async {
    if (_cargando || !widget.enabled) return; // guard contra doble-tap

    setState(() => _cargando = true);

    try {
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
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ruta = widget.rutaActual;
    final hayImagen = ruta != null && ruta.isNotEmpty;

    return hayImagen ? _vistaPrevia(ruta) : _zonaDeCarga();
  }

  /// Área punteada, visible cuando aún no se eligió imagen.
  Widget _zonaDeCarga() {
    return InkWell(
      onTap: widget.enabled && !_cargando ? _abrirExplorador : null,
      borderRadius: BorderRadius.circular(14),
      child: DottedBorder(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
          child: Column(
            children: [
              if (_cargando)
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: ColoresApp.goGreen,
                  ),
                )
              else
                const Icon(
                  Icons.upload_outlined,
                  size: 30,
                  color: ColoresApp.textDisabled,
                ),
              const SizedBox(height: 10),
              Text(
                _cargando
                    ? 'Abriendo explorador...'
                    : 'Haz clic para subir una imagen',
                style: TipografiaApp.cuerpoMedium.copyWith(
                  color: ColoresApp.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'PNG o JPG · máx. 5 MB',
                style: TipografiaApp.caption.copyWith(
                  fontSize: 12,
                  color: ColoresApp.textDisabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Miniatura + nombre del archivo + acciones, cuando ya hay imagen.
  Widget _vistaPrevia(String ruta) {
    final nombreArchivo = ruta.split(RegExp(r'[/\\]')).last;
    final existe = File(ruta).existsSync();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresApp.bgInput,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColoresApp.borderInput),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: ColoresApp.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColoresApp.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: existe
                ? Image.file(
                    File(ruta),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _ImagenRota(),
                  )
                : const _ImagenRota(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombreArchivo,
                  style: TipografiaApp.cuerpoMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  existe ? 'Imagen seleccionada' : 'No se encuentra el archivo',
                  style: TipografiaApp.caption.copyWith(
                    fontSize: 12,
                    color: existe
                        ? ColoresApp.textMuted
                        : ColoresApp.statusDanger,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          BotonIcono(
            icono: Icons.swap_horiz_rounded,
            tooltip: 'Cambiar imagen',
            alPresionar:
                widget.enabled && !_cargando ? _abrirExplorador : null,
          ),
          BotonIcono(
            icono: Icons.delete_outline_rounded,
            tooltip: 'Quitar imagen',
            color: ColoresApp.statusDanger,
            alPresionar: widget.enabled
                ? () => widget.onRutaSeleccionada(null)
                : null,
          ),
        ],
      ),
    );
  }
}

class _ImagenRota extends StatelessWidget {
  const _ImagenRota();

  @override
  Widget build(BuildContext context) => const Icon(
        Icons.broken_image_outlined,
        size: 26,
        color: ColoresApp.textDisabled,
      );
}

/// Borde punteado del área de carga.
///
/// Flutter no trae `BorderStyle.dashed`, así que se pinta a mano en lugar de
/// sumar un paquete solo por esto.
class DottedBorder extends StatelessWidget {
  const DottedBorder({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _PintorPunteado(
        color: ColoresApp.borderInput,
        radio: 14,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(color: ColoresApp.bgInput, child: child),
      ),
    );
  }
}

class _PintorPunteado extends CustomPainter {
  const _PintorPunteado({required this.color, required this.radio});

  final Color color;
  final double radio;

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final contorno = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
          Radius.circular(radio),
        ),
      );

    const guion = 7.0;
    const espacio = 5.0;

    for (final metrica in contorno.computeMetrics()) {
      var distancia = 0.0;
      while (distancia < metrica.length) {
        final hasta = (distancia + guion).clamp(0.0, metrica.length);
        canvas.drawPath(metrica.extractPath(distancia, hasta), pincel);
        distancia = hasta + espacio;
      }
    }
  }

  @override
  bool shouldRepaint(_PintorPunteado oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radio != radio;
}
