import 'package:flutter/material.dart';
import 'colores_app.dart';

class DecoracionInputsWidget {
  static InputDecoration basica({
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: ColoresApp.textLight, fontSize: 13.5),
      filled: true,
      fillColor: ColoresApp.bgContent,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: _crearBorde(ColoresApp.border),
      enabledBorder: _crearBorde(ColoresApp.border),
      focusedBorder: _crearBorde(ColoresApp.primary, ancho: 1.5),
      errorBorder: _crearBorde(ColoresApp.statusDebt),
      focusedErrorBorder: _crearBorde(ColoresApp.statusDebt, ancho: 1.5),
    );
  }

  static OutlineInputBorder _crearBorde(Color color, {double ancho = 1.0}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: ancho),
    );
  }
}