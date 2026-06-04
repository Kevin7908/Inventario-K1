import 'package:flutter/material.dart';

import '../../temas/colores_app.dart';

class EncabezadoDialogoWidget extends StatelessWidget {
  const EncabezadoDialogoWidget({
    super.key,
    required this.titulo,
    required this.icono,
    this.onCerrar,
  });
 
  final String       titulo;
  final IconData     icono;
  final VoidCallback? onCerrar;
 
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ColoresApp.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icono, color: ColoresApp.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: ColoresApp.textDark,
            ),
          ),
        ),
        if (onCerrar != null)
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: ColoresApp.textLight,
              size: 20,
            ),
            onPressed: onCerrar,
            splashRadius: 18,
          ),
      ],
    );
  }
}
