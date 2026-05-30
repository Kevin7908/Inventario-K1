import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

/// Separador de sección con ícono + línea divisoria.
class CotSeccionLabel extends StatelessWidget {
  const CotSeccionLabel({
    super.key,
    required this.icono,
    required this.label,
  });

  final IconData icono;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 14, color: ColoresApp.textMedium),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: ColoresApp.textMedium,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: ColoresApp.border)),
      ],
    );
  }
}

/// Etiqueta de campo de formulario en mayúsculas.
class CotFieldLabel extends StatelessWidget {
  const CotFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: ColoresApp.textMedium,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }
}

/// Campo de solo lectura (auto-rellenado desde relación moto→cliente).
class CotReadOnlyField extends StatelessWidget {
  const CotReadOnlyField({super.key, required this.valor});

  final String valor;

  @override
  Widget build(BuildContext context) {
    final esPlaceholder = valor.contains('Se llenará') || valor == '—';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresApp.border),
      ),
      child: Text(
        valor,
        style: TextStyle(
          color: esPlaceholder ? ColoresApp.textLight : ColoresApp.textDark,
          fontSize: 13.5,
        ),
      ),
    );
  }
}

/// Decoración estándar para inputs del diálogo.
InputDecoration cotInputDecoration({
  required String hint,
  IconData? suffixIcon,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: ColoresApp.textLight, fontSize: 13.5),
    filled: true,
    fillColor: ColoresApp.bgContent,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    suffixIcon: suffixIcon != null
        ? Icon(suffixIcon, color: ColoresApp.textLight, size: 18)
        : null,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: ColoresApp.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: ColoresApp.primary, width: 1.5),
    ),
  );
}
