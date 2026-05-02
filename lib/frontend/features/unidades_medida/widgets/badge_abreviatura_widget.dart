import 'package:flutter/material.dart';

import '../../../share/temas/colores_app.dart';

class BadgeAbreviaturaWidget extends StatelessWidget {
  const BadgeAbreviaturaWidget({super.key, required this.abreviatura});

  final String abreviatura;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ColoresApp.border),
      ),
      child: Text(
        abreviatura,
        style: const TextStyle(
          color: ColoresApp.textDark,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}