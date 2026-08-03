import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';
import 'tab_secundaria_dato.dart';

/// Grupo de pestañas para alternar entre secciones dentro de una misma pantalla.
///
/// Parámetros:
/// - [tabs]: pestañas a mostrar, en orden.
/// - [indiceActivo]: posición de la pestaña activa dentro de [tabs].
///
/// Ejemplo:
/// ```dart
/// BarraTabsSecundaria(
///   tabs: [
///     TabSecundariaDato(etiqueta: 'General', alPresionar: () => controlador.cambiarTab(0)),
///     TabSecundariaDato(etiqueta: 'Servicios', alPresionar: () => controlador.cambiarTab(1)),
///   ],
///   indiceActivo: controlador.tabActivo,
/// )
/// ```
class BarraTabsSecundaria extends StatelessWidget {
  const BarraTabsSecundaria({
    super.key,
    required this.tabs,
    required this.indiceActivo,
  });

  final List<TabSecundariaDato> tabs;
  final int indiceActivo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColoresApp.border),
      ),
      // `Wrap` en vez de `Row`: con espacio suficiente se ve como una sola
      // fila que abraza su contenido, y en ventanas angostas las pestañas
      // pasan a la línea siguiente en lugar de desbordar.
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < tabs.length; i++)
            _TabItem(dato: tabs[i], activo: i == indiceActivo),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.dato, required this.activo});

  final TabSecundariaDato dato;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: activo ? ColoresApp.blackChocolate : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: dato.alPresionar,
        borderRadius: BorderRadius.circular(10),
        hoverColor: ColoresApp.bgCardHover,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Text(
            dato.etiqueta,
            style: activo
                ? TipografiaApp.sobrePrimario(TipografiaApp.cuerpoMedium)
                : TipografiaApp.cuerpoMedium.copyWith(
                    color: ColoresApp.textSecondary,
                  ),
          ),
        ),
      ),
    );
  }
}
