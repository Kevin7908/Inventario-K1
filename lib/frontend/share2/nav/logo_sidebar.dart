import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Encabezado del sidebar con el logo SVG de K1, nombre de empresa y subtítulo.
///
/// Parámetros:
/// - [nombreEmpresa]: nombre principal mostrado en negrita.
/// - [subtitulo]: descripción debajo del nombre (ej. tipo de negocio).
///
/// Ejemplo:
/// ```dart
/// const LogoSidebar()
/// LogoSidebar(nombreEmpresa: 'MiTaller', subtitulo: 'Motos y repuestos')
/// ```
class LogoSidebar extends StatelessWidget {
  const LogoSidebar({
    super.key,
    this.nombreEmpresa = 'InventarioK1',
    this.subtitulo = 'Taller de motos',
  });

  final String nombreEmpresa;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/images/logo-k1.svg',
            width: 40,
            height: 40,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombreEmpresa,
                style: TipografiaApp.cuerpoMedium.copyWith(
                  color: ColoresApp.textOnPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitulo,
                style: TipografiaApp.caption.copyWith(
                  color: ColoresApp.textSidebar,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

