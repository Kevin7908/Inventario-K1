import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../share2/share2.dart';

/// El marco visual que comparten el login, el alta del primer administrador y
/// la recuperación de la contraseña.
///
/// Son tres pantallas con el mismo esqueleto: a la izquierda el panel oscuro
/// de la marca —el mismo `bgSidebar` del sidebar de la app, para que entrar no
/// parezca otro programa—, a la derecha el formulario centrado. Por debajo de
/// 900 px de ancho el panel se va y queda solo el formulario.
///
/// Vive en el módulo y no en `share2` porque solo lo usan estas tres
/// pantallas y porque conoce el logo de la app.
///
/// Parámetros:
/// - [titulo] y [subtitulo]: encabezan el formulario.
/// - [child]: el formulario.
/// - [alVolver]: si se pasa, aparece la flecha de regreso sobre el título.
/// - [etiquetaVolver]: texto de esa flecha.
///
/// Ejemplo:
/// ```dart
/// MarcoAutenticacion(
///   titulo: 'Entra a tu cuenta',
///   subtitulo: 'Con tu usuario o tu correo.',
///   child: _FormularioLogin(),
/// )
/// ```
class MarcoAutenticacion extends StatelessWidget {
  const MarcoAutenticacion({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.child,
    this.alVolver,
    this.etiquetaVolver = 'Volver',
  });

  static const double _anchoPanel = 420;
  static const double _anchoMinimoConPanel = 900;

  final String titulo;
  final String subtitulo;
  final Widget child;
  final VoidCallback? alVolver;
  final String etiquetaVolver;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.bgCard,
      body: LayoutBuilder(
        builder: (context, restricciones) {
          final cabePanel =
              restricciones.maxWidth >= _anchoMinimoConPanel;

          return Row(
            children: [
              if (cabePanel)
                const SizedBox(width: _anchoPanel, child: _PanelMarca()),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 40,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!cabePanel) ...[
                            const _LogoCompacto(),
                            const SizedBox(height: 28),
                          ],
                          if (alVolver != null) ...[
                            BotonVolver(
                              etiqueta: etiquetaVolver,
                              alPresionar: alVolver!,
                            ),
                            const SizedBox(height: 12),
                          ],
                          Text(titulo, style: TipografiaApp.heading2),
                          const SizedBox(height: 6),
                          Text(
                            subtitulo,
                            style: TipografiaApp.subtituloPagina,
                          ),
                          const SizedBox(height: 28),
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// El panel oscuro de la izquierda: logo, nombre y qué es esta app.
class _PanelMarca extends StatelessWidget {
  const _PanelMarca();

  static const List<(IconData, String)> _puntos = [
    (Icons.inventory_2_outlined, 'Inventario y repuestos al día'),
    (Icons.build_outlined, 'Órdenes de servicio del taller'),
    (Icons.attach_money_rounded, 'Ventas, cotizaciones y cartera'),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ColoresApp.bgSidebar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(44, 44, 44, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SvgPicture.asset(
                  'assets/images/logo-k1.svg',
                  width: 44,
                  height: 44,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'InventarioK1',
                      style: TipografiaApp.subtitulo.copyWith(
                        color: ColoresApp.textOnPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Taller de motos',
                      style: TipografiaApp.caption.copyWith(
                        color: ColoresApp.textSidebarSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            Text(
              'Todo el taller\nen un solo sitio.',
              style: TipografiaApp.heading1.copyWith(
                color: ColoresApp.textOnPrimary,
                fontSize: 30,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 24),
            for (final (icono, texto) in _puntos)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(icono, size: 18, color: ColoresApp.brightGreen),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        texto,
                        style: TipografiaApp.cuerpo.copyWith(
                          color: ColoresApp.textSidebar,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            Text(
              'Los datos se guardan en este equipo.',
              style: TipografiaApp.caption.copyWith(
                color: ColoresApp.textSidebarLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El logo en horizontal, para cuando la ventana es muy angosta y el panel
/// oscuro no cabe.
class _LogoCompacto extends StatelessWidget {
  const _LogoCompacto();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SvgPicture.asset('assets/images/logo-k1.svg', width: 36, height: 36),
        const SizedBox(width: 10),
        Text(
          'InventarioK1',
          style: TipografiaApp.subtitulo.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
