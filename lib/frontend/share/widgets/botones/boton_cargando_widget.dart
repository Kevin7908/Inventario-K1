import 'package:flutter/material.dart';

import '../../temas/colores_app.dart';

class BotonCargando extends StatelessWidget {
  final String etiqueta;
  final VoidCallback? alPresionar;
  final bool estaCargando;
  final double ancho;
  final double alto;
  final IconData? icono;
  final Color colorFondo;
  final Color colorTexto;

  const BotonCargando({
    super.key,
    required this.etiqueta,
    required this.alPresionar,
    this.estaCargando = false,
    this.ancho = double.infinity,
    this.alto = 48,
    this.icono,
    this.colorFondo = ColoresApp.primary,
    this.colorTexto = ColoresApp.textWhite,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      height: alto,
      child: ElevatedButton(
        onPressed: estaCargando ? null : alPresionar,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorFondo,
          disabledBackgroundColor: colorFondo.withOpacity(0.6),
          foregroundColor: colorTexto,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: estaCargando
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorTexto.withOpacity(0.8),
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icono != null) ...[
                    Icon(icono, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    etiqueta,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorTexto,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}