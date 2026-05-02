import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../share/temas/colores_app.dart';

/// Widget atómico y sin estado para cada celda del código OTP.
/// Es eficiente porque no depende de ningún Provider ni setState externo:
/// toda su interactividad se delega hacia arriba mediante callbacks.
class CajaOtp extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  const CajaOtp({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
  });

  // Decoración compartida — se construye una sola vez por instancia.
  static InputDecoration _decoration() => InputDecoration(
        filled: true,
        fillColor: ColoresApp.bgContent,
        contentPadding: EdgeInsets.zero,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ColoresApp.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ColoresApp.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ColoresApp.primary, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 60,
      child: KeyboardListener(
        // FocusNode interno propio del KeyboardListener, no del campo de texto.
        focusNode: FocusNode(),
        onKeyEvent: (e) {
          if (e is KeyDownEvent &&
              e.logicalKey == LogicalKeyboardKey.backspace) {
            onBackspace();
          }
        },
        child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            // Permite pegar los 6 dígitos de una vez (el padre los distribuye).
            LengthLimitingTextInputFormatter(6),
          ],
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: ColoresApp.textDark,
          ),
          decoration: _decoration(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}