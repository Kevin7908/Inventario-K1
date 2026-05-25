import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

// Diálogo genérico de confirmación para eliminar cualquier elemento
class DialogoConfirmarEliminar extends StatelessWidget {
  final String nombreElemento;
  final String tipoElemento;
  final VoidCallback onConfirmar;

  const DialogoConfirmarEliminar({
    super.key,
    required this.nombreElemento,
    required this.tipoElemento,
    required this.onConfirmar,
  });

  static Future<void> mostrar({
    required BuildContext context,
    required String nombreElemento,
    required String tipoElemento,
    required VoidCallback onConfirmar,
  }) {
    return showDialog(
      context: context,
      builder: (_) => DialogoConfirmarEliminar(
        nombreElemento: nombreElemento,
        tipoElemento: tipoElemento,
        onConfirmar: onConfirmar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícono de advertencia
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: ColoresApp.statusDebtBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: ColoresApp.statusDebt,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Eliminar $tipoElemento',
              style: const TextStyle(
                color: ColoresApp.textDark,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              '¿Estás seguro de que deseas eliminar "$nombreElemento"? Esta acción no se puede deshacer.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ColoresApp.textMedium,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColoresApp.textMedium,
                      side: const BorderSide(color: ColoresApp.border),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirmar();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColoresApp.statusDebt,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Sí, eliminar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
