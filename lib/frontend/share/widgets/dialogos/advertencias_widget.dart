import 'package:flutter/material.dart';

import '../../temas/colores_app.dart';

class DialogBannerAdvertencia extends StatelessWidget {
  const DialogBannerAdvertencia({super.key, required this.mensaje});
  final String mensaje;
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ColoresApp.statusPendingBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ColoresApp.statusPending.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: ColoresApp.statusPending,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(
                color: ColoresApp.statusPending,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
