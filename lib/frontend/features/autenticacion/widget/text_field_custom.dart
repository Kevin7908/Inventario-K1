import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../share/temas/colores_app.dart';

class TextFieldCustom extends StatelessWidget {
  final String etiqueta;
  final String? hint;
  final TextEditingController controlador;
  final FocusNode? focusNode;
  final FocusNode? siguienteFoco;

  final ValueNotifier<bool>? mostrarPasswordNotifier;

  final String? Function(String?)? validador;
  final TextInputType tipoTeclado;
  final bool habilitado;
  final IconData? iconoPrefijo;
  final VoidCallback? alPresionarEnter;
  final List<TextInputFormatter>? formatters;
  final int maxLineas;

  const TextFieldCustom({
    super.key,
    required this.etiqueta,
    required this.controlador,
    this.hint,
    this.focusNode,
    this.siguienteFoco,
    this.mostrarPasswordNotifier,
    this.validador,
    this.tipoTeclado = TextInputType.text,
    this.habilitado = true,
    this.iconoPrefijo,
    this.alPresionarEnter,
    this.formatters,
    this.maxLineas = 1,
  });

  bool get _esCampoPassword => mostrarPasswordNotifier != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ColoresApp.textDark,
          ),
        ),
        const SizedBox(height: 6),
        _esCampoPassword ? _buildPasswordField() : _buildTextField(),
      ],
    );
  }

  Widget _buildTextField() {
    return TextFormField(
      controller: controlador,
      focusNode: focusNode,
      enabled: habilitado,
      keyboardType: tipoTeclado,
      inputFormatters: formatters,
      maxLines: maxLineas,
      textInputAction:
          siguienteFoco != null ? TextInputAction.next : TextInputAction.done,
      style: const TextStyle(
        fontSize: 14,
        color: ColoresApp.textDark,
      ),
      decoration: _decoracion(sufijo: null),
      validator: validador,
      onFieldSubmitted: (_) {
        if (siguienteFoco != null) {
          siguienteFoco!.requestFocus();
        } else {
          alPresionarEnter?.call();
        }
      },
    );
  }

  Widget _buildPasswordField() {
    // ValueListenableBuilder reconstruye SOLO el ícono de visibilidad,
    // no el TextFormField completo → evita pérdida de foco y rebuilds innecesarios.
    return ValueListenableBuilder<bool>(
      valueListenable: mostrarPasswordNotifier!,
      builder: (_, mostrar, __) {
        return TextFormField(
          controller: controlador,
          focusNode: focusNode,
          enabled: habilitado,
          obscureText: !mostrar,
          textInputAction: siguienteFoco != null
              ? TextInputAction.next
              : TextInputAction.done,
          style: const TextStyle(
            fontSize: 14,
            color: ColoresApp.textDark,
          ),
          decoration: _decoracion(
            sufijo: IconButton(
              icon: Icon(
                mostrar
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: ColoresApp.textLight,
              ),
              onPressed: () {
                mostrarPasswordNotifier!.value = !mostrarPasswordNotifier!.value;
              },
              tooltip: mostrar ? 'Ocultar contraseña' : 'Mostrar contraseña',
            ),
          ),
          validator: validador,
          onFieldSubmitted: (_) {
            if (siguienteFoco != null) {
              siguienteFoco!.requestFocus();
            } else {
              alPresionarEnter?.call();
            }
          },
        );
      },
    );
  }

  InputDecoration _decoracion({required Widget? sufijo}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 14,
        color: ColoresApp.textLight,
      ),
      prefixIcon: iconoPrefijo != null
          ? Icon(iconoPrefijo, size: 18, color: ColoresApp.textLight)
          : null,
      suffixIcon: sufijo,
      filled: true,
      fillColor: ColoresApp.bgContent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ColoresApp.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ColoresApp.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ColoresApp.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ColoresApp.statusDebt),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ColoresApp.statusDebt, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: ColoresApp.border.withOpacity(0.5)),
      ),
      errorStyle: const TextStyle(
        fontSize: 11,
        color: ColoresApp.statusDebt,
      ),
    );
  }
}