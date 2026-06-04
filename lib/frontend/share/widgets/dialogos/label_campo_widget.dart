import 'package:flutter/material.dart';

import '../../temas/colores_app.dart';

class LabelCampoWidget extends StatelessWidget {
  const LabelCampoWidget({super.key, required this.texto});
  final String texto;
 
  @override
  Widget build(BuildContext context) => Text(
        texto,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: ColoresApp.textMedium,
        ),
      );
}
