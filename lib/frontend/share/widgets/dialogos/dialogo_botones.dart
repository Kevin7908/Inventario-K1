import 'package:flutter/material.dart';

import '../../temas/colores_app.dart';

class DialogBotones extends StatelessWidget {
  const DialogBotones({
    super.key,
    required this.guardando,
    required this.onCancelar,
    required this.onGuardar,
    this.textoGuardar = 'Guardar',
  });
 
  final bool         guardando;
  final VoidCallback onCancelar;
  final VoidCallback onGuardar;
  final String       textoGuardar;
 
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: guardando ? null : onCancelar,
          style: TextButton.styleFrom(
            foregroundColor: ColoresApp.textMedium,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('Cancelar'),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: guardando ? null : onGuardar,
          style: FilledButton.styleFrom(
            backgroundColor: ColoresApp.primary,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(textoGuardar),
        ),
      ],
    );
  }
}
 
