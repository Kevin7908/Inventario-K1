import 'package:flutter/material.dart';

class BadgeTipo extends StatelessWidget {
  const BadgeTipo({super.key, required this.tipo, required this.color});

  final String tipo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tipo,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
