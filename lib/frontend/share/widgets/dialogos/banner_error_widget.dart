import 'package:flutter/material.dart';

import '../../temas/colores_app.dart';

class BannerErrorWidget extends StatelessWidget {
  const BannerErrorWidget({super.key, required this.mensaje});
  final String mensaje;
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ColoresApp.statusDebtBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ColoresApp.statusDebt.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: ColoresApp.statusDebt,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(
                color: ColoresApp.statusDebt,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
