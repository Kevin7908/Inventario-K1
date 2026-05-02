import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

class SnackBarMensaje {
  static void success(BuildContext context, String mensaje) {
    _show(context, mensaje, ColoresApp.statusPaid);
  }

  static void error(BuildContext context, String mensaje) {
    _show(context, mensaje, ColoresApp.statusDebt);
  }

  static void _show(BuildContext context, String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
