import 'package:flutter/material.dart';

import '../../temas/colores_app.dart';

class BotonMasWidget extends StatelessWidget {
  const BotonMasWidget({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Agregar nuevo',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 44,
          decoration: BoxDecoration(
            color: ColoresApp.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ColoresApp.primary.withOpacity(0.3)),
          ),
          child: const Icon(
            Icons.add_rounded,
            size: 18,
            color: ColoresApp.primary,
          ),
        ),
      ),
    );
  }
}
