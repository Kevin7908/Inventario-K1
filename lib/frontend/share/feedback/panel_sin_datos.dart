import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// El cajón que rellena un `PanelSeccion` mientras no hay nada que pintar:
/// porque todavía no pasó nada, porque falló la consulta, o porque está
/// cargando.
///
/// Es el hermano chico de [EstadoVacio]. Aquél es el bloque centrado de una
/// pantalla entera —ícono grande, título y pista, sin marco—; éste vive
/// **dentro** de un panel de la ficha, donde lo que hace falta es que el
/// hueco tenga la misma altura y el mismo borde que tendría la lista, para
/// que la ficha no cambie de forma al llegar los datos.
///
/// Parámetros:
/// - [icono]: el del contenido que falta. Se ignora si [cargando] es `true`.
/// - [texto]: una línea diciendo qué falta. Se ignora si [cargando].
/// - [cargando]: en `true` pinta el indicador de progreso en vez del ícono.
///
/// Ejemplo:
/// ```dart
/// PanelSeccion(
///   titulo: 'Movimientos recientes',
///   child: switch (movimientos) {
///     AsyncData(value: final lista) when lista.isEmpty => const PanelSinDatos(
///         icono: Icons.swap_vert_rounded,
///         texto: 'Aún no se registran movimientos',
///       ),
///     AsyncData(value: final lista) => _Lista(movimientos: lista),
///     _ => const PanelSinDatos.cargando(),
///   },
/// )
/// ```
class PanelSinDatos extends StatelessWidget {
  const PanelSinDatos({
    super.key,
    required IconData this.icono,
    required String this.texto,
  }) : cargando = false;

  /// El mismo cajón, con el indicador de progreso dentro.
  const PanelSinDatos.cargando({super.key})
      : icono = null,
        texto = null,
        cargando = true;

  final IconData? icono;
  final String? texto;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      decoration: BoxDecoration(
        color: ColoresApp.bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.borderFila),
      ),
      child: Center(
        child: cargando
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icono, size: 26, color: ColoresApp.textDisabled),
                  const SizedBox(height: 8),
                  Text(
                    texto!,
                    style: TipografiaApp.caption.copyWith(
                      color: ColoresApp.textDisabled,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
}
