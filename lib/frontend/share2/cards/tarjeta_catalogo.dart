import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Tarjeta de un ítem de catálogo dentro de una grilla: ícono en caja
/// redondeada, nombre, dato secundario y acciones opcionales a la derecha.
///
/// Pensada para catálogos simples que se leen de un vistazo
/// (especializaciones, categorías, formas de pago), donde una tabla sería
/// demasiado pesada.
///
/// Parámetros:
/// - [icono]: ícono mostrado en la caja de la izquierda.
/// - [titulo]: nombre del ítem.
/// - [subtitulo]: dato secundario debajo del título (ej. "3 técnicos").
/// - [acciones]: widget alineado a la derecha (ej. botones de editar/eliminar).
/// - [colorIcono]: color del ícono. Por defecto `ColoresApp.goGreen`.
/// - [colorFondoIcono]: fondo de la caja del ícono. Por defecto `ColoresApp.greenChipBg`.
/// - [alPresionar]: callback opcional al tocar la tarjeta.
/// - [lineasTitulo]: máximo de líneas del título antes de recortar con "…".
///   Por defecto 2, para que los nombres largos bajen de línea en vez de
///   cortarse. La grilla que la contiene debe reservar alto para esas líneas.
///
/// Ejemplo:
/// ```dart
/// TarjetaCatalogo(
///   icono: Icons.build_outlined,
///   titulo: 'Motor',
///   subtitulo: '3 técnicos',
///   acciones: BotonIcono(
///     icono: Icons.edit_outlined,
///     tooltip: 'Editar',
///     alPresionar: () => controlador.editar(item),
///   ),
/// )
/// ```
class TarjetaCatalogo extends StatelessWidget {
  const TarjetaCatalogo({
    super.key,
    required this.icono,
    required this.titulo,
    this.subtitulo,
    this.acciones,
    this.colorIcono,
    this.colorFondoIcono,
    this.alPresionar,
    this.lineasTitulo = 2,
  });

  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final Widget? acciones;
  final Color? colorIcono;
  final Color? colorFondoIcono;
  final VoidCallback? alPresionar;
  final int lineasTitulo;

  @override
  Widget build(BuildContext context) {
    final contenido = Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorFondoIcono ?? ColoresApp.greenChipBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icono,
              size: 20,
              color: colorIcono ?? ColoresApp.goGreen,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TipografiaApp.tituloTarjeta,
                  maxLines: lineasTitulo,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
                if (subtitulo != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitulo!,
                    style: TipografiaApp.caption.copyWith(
                      fontSize: 12,
                      color: ColoresApp.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          ?acciones,
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresApp.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: alPresionar == null
          ? contenido
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: alPresionar,
                hoverColor: ColoresApp.bgCardHover,
                child: contenido,
              ),
            ),
    );
  }
}
