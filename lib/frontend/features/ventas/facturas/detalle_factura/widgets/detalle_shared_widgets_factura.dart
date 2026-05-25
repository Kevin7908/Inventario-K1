import 'package:flutter/material.dart';

import '../../../../../../frontend/share/temas/colores_app.dart';

class SeccionHeaderFactura extends StatelessWidget {
  const SeccionHeaderFactura({
    super.key,
    required this.titulo,
    required this.icono,
    this.accion,
  });

  final String titulo;
  final IconData icono;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        border: Border(bottom: BorderSide(color: Color(0xFFDBEAFE))),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: ColoresApp.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            titulo.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: ColoresApp.primary,
            ),
          ),
          if (accion != null) ...[
            const Spacer(),
            accion!,
          ],
        ],
      ),
    );
  }
}

class EstadoVacioSeccionFactura extends StatelessWidget {
  const EstadoVacioSeccionFactura({super.key, required this.mensaje});
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          mensaje,
          style: const TextStyle(
            fontSize: 13,
            color: ColoresApp.textLight,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

class EncabezadoColFac extends StatelessWidget {
  const EncabezadoColFac(this.texto, {super.key, this.center = false, this.right = false});
  final String texto;
  final bool center;
  final bool right;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto.toUpperCase(),
      textAlign: right
          ? TextAlign.right
          : center
              ? TextAlign.center
              : TextAlign.left,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: ColoresApp.textLight,
      ),
    );
  }
}

class MiniBotonFac extends StatelessWidget {
  const MiniBotonFac({
    super.key,
    required this.icono,
    required this.color,
    required this.onTap,
  });
  final IconData icono;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Icon(icono, size: 15, color: color),
      ),
    );
  }
}

class InfoCellFac extends StatelessWidget {
  const InfoCellFac({super.key, required this.etiqueta, required this.valor, this.valorWidget});
  final String etiqueta;
  final String valor;
  final Widget? valorWidget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: ColoresApp.textLight,
            ),
          ),
          const SizedBox(height: 6),
          valorWidget ??
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 13,
                  color: ColoresApp.textDark,
                  height: 1.5,
                ),
              ),
        ],
      ),
    );
  }
}
