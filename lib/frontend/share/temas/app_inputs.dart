import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

class AppInputs {
  AppInputs._();

  static InputDecoration decoracion({
    String? hint,
    String? label,
    IconData? icono,
    Widget? suffixIcon,
    bool hasError = false,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hint,
      labelText: label,
      hintStyle: const TextStyle(color: ColoresApp.textLight, fontSize: 13.5),
      labelStyle:
          const TextStyle(color: ColoresApp.textLight, fontSize: 13.5),
      prefixIcon: icono != null
          ? Icon(icono, size: 18, color: ColoresApp.textLight)
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: ColoresApp.bgContent,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ColoresApp.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: hasError ? ColoresApp.statusDebt : ColoresApp.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ColoresApp.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ColoresApp.statusDebt),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: ColoresApp.statusDebt, width: 1.5),
      ),
      errorText: errorText,
    );
  }
}
