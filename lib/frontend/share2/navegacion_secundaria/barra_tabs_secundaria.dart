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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresApp.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
      color: activo ? ColoresApp.textPrimary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: dato.alPresionar,
        borderRadius: BorderRadius.circular(8),
        hoverColor: ColoresApp.bgCardHover,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
