import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';
import 'marcador_identidad.dart';

/// Ficha compacta de a quién pertenece un documento, y atajo para cambiarlo.
///
/// Resuelve el hueco entre un campo de formulario y un texto suelto: en los
/// paneles de 360 px del punto de venta y del editor de cotizaciones, tres
/// campos apilados con su etiqueta se comen media pantalla, pero un texto
/// plano no deja claro que se pueda tocar. Esta ficha ocupa una sola fila,
/// muestra lo que hay elegido y abre el selector al tocarla.
///
/// Toda la ficha es **un solo objetivo de clic**: no hay un botón dentro de
/// otro. El ícono de la derecha es decorativo y el `tooltip` lo lleva la ficha
/// entera, que es lo que se pulsa.
///
/// Parámetros:
/// - [titulo]: línea principal (el nombre del cliente, o "Mostrador").
/// - [subtitulo]: línea tenue de abajo (la placa, la vigencia). Opcional.
/// - [inicial]: una o dos letras para el marcador. La usa quien tiene algo
///   elegido.
/// - [icono]: ícono del marcador cuando no hay nada elegido. Tiene prioridad
///   sobre [inicial], igual que en [MarcadorIdentidad].
/// - [tenue]: pinta el título con el gris de placeholder. Para el estado "sin
///   elegir", donde [titulo] es un valor por defecto y no un dato real.
/// - [alPresionar]: abre el selector. Si es `null`, la ficha no responde.
/// - [etiquetaAccion]: tooltip de la ficha. Obligatorio: dice qué pasa al
///   tocarla ("Cambiar el cliente").
/// - [iconoAccion]: ícono decorativo de la derecha. Por defecto, un lápiz.
///
/// Ejemplo:
/// ```dart
/// FichaResumen(
///   titulo: cliente?.nombreCompleto ?? 'Mostrador',
///   subtitulo: moto?.placa,
///   inicial: inicialDe(cliente?.nombreCompleto),
///   icono: cliente == null ? Icons.storefront_outlined : null,
///   tenue: cliente == null,
///   etiquetaAccion: 'Cambiar el cliente',
///   alPresionar: _elegirCliente,
/// )
/// ```
class FichaResumen extends StatelessWidget {
  const FichaResumen({
    super.key,
    required this.titulo,
    this.etiquetaAccion,
    this.alPresionar,
    this.subtitulo,
    this.inicial,
    this.icono,
    this.tenue = false,
    this.iconoAccion = Icons.edit_outlined,
  });

  final String titulo;
  /// Qué pasa al tocarla, para el tooltip. **Sin [alPresionar] la ficha es
  /// solo lectura**: no lleva lápiz ni tooltip, porque prometer una acción que
  /// no existe es peor que no ofrecerla. Así sirve igual de cabecera editable
  /// que de bloque de contexto.
  final String? etiquetaAccion;
  final VoidCallback? alPresionar;
  final String? subtitulo;
  final String? inicial;
  final IconData? icono;
  final bool tenue;
  final IconData iconoAccion;

  @override
  Widget build(BuildContext context) {
    final detalle = subtitulo;

    final ficha = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: alPresionar,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ColoresApp.bgInput,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColoresApp.borderInput),
            ),
            child: Row(
              children: [
                MarcadorIdentidad(
                  icono: icono,
                  inicial: inicial,
                  color: tenue ? ColoresApp.textDisabled : null,
                  colorFondo: tenue ? ColoresApp.bgApp : null,
                  lado: 36,
                  radio: 10,
                  tamanoContenido: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        titulo,
                        style: tenue
                            ? TipografiaApp.deshabilitado(
                                TipografiaApp.cuerpoMedium,
                              )
                            : TipografiaApp.cuerpoMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (detalle != null && detalle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          detalle,
                          style: TipografiaApp.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (alPresionar != null) ...[
                  const SizedBox(width: 8),
                  Icon(iconoAccion, size: 16, color: ColoresApp.textDisabled),
                ],
              ],
            ),
          ),
        ),
    );

    final etiqueta = etiquetaAccion;
    if (etiqueta == null || alPresionar == null) return ficha;
    return Tooltip(message: etiqueta, child: ficha);
  }
}
