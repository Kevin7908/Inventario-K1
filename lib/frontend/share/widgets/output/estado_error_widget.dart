import 'package:flutter/material.dart';

import '../../temas/colores_app.dart';

class EstadoErrorWidget extends StatelessWidget {
  final String mensaje;
  final VoidCallback alReintentar;

  const EstadoErrorWidget({
    super.key,
    required this.mensaje,
    required this.alReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: ColoresApp.statusDebtBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: ColoresApp.statusDebt,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ocurrió un error',
              style: TextStyle(
                color: ColoresApp.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mensaje,
              style: const TextStyle(
                color: ColoresApp.textMedium,
                fontSize: 13.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: alReintentar,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColoresApp.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
