import 'dart:io';

import 'package:flutter/material.dart';

import '../../../share/temas/colores_app.dart';

class VistaPreviaImagen extends StatelessWidget {
  const VistaPreviaImagen({
    super.key,
    required this.imagenUrl,
    this.altura = 200,
    this.cacheWidth = 600,
  });

  final String? imagenUrl;
  final double altura;

  /// Ancho de decodificación en píxeles de imagen.
  /// Por defecto 600 px (cubre 200 dp en pantallas 3×).
  /// Pásalo explícitamente si el widget se usa en un contexto más pequeño.
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: altura,
        width: double.infinity,
        color: ColoresApp.bgContent,
        child: _buildContenido(),
      ),
    );
  }

  Widget _buildContenido() {
    if (imagenUrl == null || imagenUrl!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: ColoresApp.textLight,
            ),
            SizedBox(height: 8),
            Text(
              'Sin imagen',
              style: TextStyle(
                color: ColoresApp.textLight,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (imagenUrl!.startsWith('http://') ||
        imagenUrl!.startsWith('https://')) {
      return Image.network(
        imagenUrl!,
        fit: BoxFit.contain,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => const _IconoImagenRota(),
      );
    }

    // OPTIMIZACIÓN RAM: cacheWidth limita la resolución de decodificación.
    // En la vista de detalle (200 dp de alto, ancho ~520 dp en dialog):
    // cacheWidth: 600 cubre pantallas hasta 3× sin desperdiciar RAM.
    return Image.file(
      File(imagenUrl!),
      fit: BoxFit.contain,
      cacheWidth: cacheWidth,
      errorBuilder: (_, _, _) => const _IconoImagenRota(),
    );
  }
}

class _IconoImagenRota extends StatelessWidget {
  const _IconoImagenRota();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.broken_image_outlined,
        size: 40,
        color: ColoresApp.textLight,
      ),
    );
  }
}