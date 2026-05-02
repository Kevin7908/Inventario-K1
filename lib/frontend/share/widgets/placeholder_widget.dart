import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/share/nav/nav_section.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

class PlaceholderWidget extends StatelessWidget {
  final NavSection seccion;
  const PlaceholderWidget({super.key, required this.seccion});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.construction_rounded,
            size: 48,
            color: ColoresApp.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            seccion.name.toUpperCase(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Text('Vista en construcción'),
        ],
      ),
    );
  }
}
