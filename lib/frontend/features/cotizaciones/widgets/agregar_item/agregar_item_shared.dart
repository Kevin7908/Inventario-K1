import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

/// Encabezado reutilizable para los diálogos de agregar ítem.
class AgregarItemHeader extends StatelessWidget {
  const AgregarItemHeader({
    super.key,
    required this.titulo,
    required this.icono,
    required this.onCerrar,
  });

  final String titulo;
  final IconData icono;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: ColoresApp.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icono, color: ColoresApp.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ColoresApp.textDark,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded,
              color: ColoresApp.textLight, size: 20),
          onPressed: onCerrar,
        ),
      ],
    );
  }
}

/// Etiqueta de campo dentro de los diálogos de agregar ítem.
class AgregarItemLabel extends StatelessWidget {
  const AgregarItemLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: ColoresApp.textMedium,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }
}

/// Campo numérico estilizado para los diálogos de agregar ítem.
class AgregarNumericField extends StatelessWidget {
  const AgregarNumericField({
    super.key,
    required this.controller,
    this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(color: ColoresApp.textDark, fontSize: 13.5),
      decoration: InputDecoration(
        filled: true,
        fillColor: ColoresApp.bgContent,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ColoresApp.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ColoresApp.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// Fila de subtotal calculado (solo lectura).
class AgregarSubtotalRow extends StatelessWidget {
  const AgregarSubtotalRow({super.key, required this.subtotal});

  final int subtotal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Subtotal',
            style: TextStyle(color: ColoresApp.textMedium, fontSize: 13),
          ),
          Text(
            subtotal.toCopString(),
            style: const TextStyle(
              color: ColoresApp.textDark,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botones de Cancelar / Confirmar reutilizables.
class AgregarItemBotones extends StatelessWidget {
  const AgregarItemBotones({
    super.key,
    required this.cargando,
    required this.habilitado,
    required this.onCancelar,
    required this.onAgregar,
    this.labelAgregar = 'Agregar',
  });

  final bool cargando;
  final bool habilitado;
  final VoidCallback onCancelar;
  final VoidCallback onAgregar;
  final String labelAgregar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancelar,
            style: OutlinedButton.styleFrom(
              foregroundColor: ColoresApp.textMedium,
              side: const BorderSide(color: ColoresApp.border),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancelar'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: (cargando || !habilitado) ? null : onAgregar,
            style: ElevatedButton.styleFrom(
              backgroundColor: ColoresApp.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: cargando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(labelAgregar),
          ),
        ),
      ],
    );
  }
}
