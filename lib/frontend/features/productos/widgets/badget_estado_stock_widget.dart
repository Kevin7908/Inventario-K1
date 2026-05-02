import 'package:flutter/material.dart';

import '../../../../backend/features/productos/modelo/producto.dart';

class BadgeEstadoStock extends StatelessWidget {
  const BadgeEstadoStock({super.key, required this.estado});

  final EstadoStock estado;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (estado) {
      EstadoStock.enStock => ('En stock', const Color(0xFF10B981)),
      EstadoStock.stockBajo => ('Stock bajo', const Color(0xFFF59E0B)),
      EstadoStock.sinStock => ('Sin stock', const Color(0xFFEF4444)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}