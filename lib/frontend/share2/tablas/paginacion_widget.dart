import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Navegación entre páginas de una colección paginada.
///
/// Se combina con [TablaGenerica] pasándole solo los ítems de la página
/// actual (ya recortados por el controlador del módulo), de forma que la
/// tabla nunca construye más filas de las que caben en una página.
///
/// Parámetros:
/// - [paginaActual]: índice 0-based de la página mostrada.
/// - [totalPaginas]: cantidad total de páginas (mínimo 1).
/// - [alCambiarPagina]: callback que recibe el nuevo índice de página.
/// - [totalItems]: total de ítems sin paginar. Si se define junto con
///   [itemsPorPagina], se muestra el rango ("Mostrando 1–20 de 97").
/// - [itemsPorPagina]: tamaño de página usado para calcular el rango mostrado.
///
/// Ejemplo:
/// ```dart
/// final inicio = paginaActual * itemsPorPagina;
/// final itemsPagina = items.skip(inicio).take(itemsPorPagina).toList();
///
/// Column(
///   children: [
///     Expanded(child: TablaGenerica(items: itemsPagina, columnas: columnas)),
///     PaginacionWidget(
///       paginaActual: paginaActual,
///       totalPaginas: (items.length / itemsPorPagina).ceil(),
///       totalItems: items.length,
///       itemsPorPagina: itemsPorPagina,
///       alCambiarPagina: (p) => controlador.irAPagina(p),
///     ),
///   ],
/// )
/// ```
class PaginacionWidget extends StatelessWidget {
  const PaginacionWidget({
    super.key,
    required this.paginaActual,
    required this.totalPaginas,
    required this.alCambiarPagina,
    this.totalItems,
    this.itemsPorPagina,
  });

  final int paginaActual;
  final int totalPaginas;
  final ValueChanged<int> alCambiarPagina;
  final int? totalItems;
  final int? itemsPorPagina;

  @override
  Widget build(BuildContext context) {
    final bool tieneAnterior = paginaActual > 0;
    final bool tieneSiguiente = paginaActual < totalPaginas - 1;
    final int paginasMostradas = totalPaginas < 1 ? 1 : totalPaginas;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (totalItems != null && itemsPorPagina != null)
            Text(_textoRango(), style: TipografiaApp.caption)
          else
            const SizedBox.shrink(),
          Row(
            children: [
              _BotonPagina(
                icono: Icons.chevron_left_rounded,
                alPresionar: tieneAnterior
                    ? () => alCambiarPagina(paginaActual - 1)
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                'Página ${paginaActual + 1} de $paginasMostradas',
                style: TipografiaApp.cuerpoMedium,
              ),
              const SizedBox(width: 12),
              _BotonPagina(
                icono: Icons.chevron_right_rounded,
                alPresionar: tieneSiguiente
                    ? () => alCambiarPagina(paginaActual + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _textoRango() {
    final int total = totalItems!;
    if (total <= 0) return 'Mostrando 0 de 0';

    final int porPagina = itemsPorPagina!;
    final int inicio = paginaActual * porPagina + 1;
    final int fin = (inicio + porPagina - 1).clamp(0, total);
    return 'Mostrando $inicio–$fin de $total';
  }
}

class _BotonPagina extends StatelessWidget {
  const _BotonPagina({required this.icono, required this.alPresionar});

  final IconData icono;
  final VoidCallback? alPresionar;

  @override
  Widget build(BuildContext context) {
    final bool deshabilitado = alPresionar == null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: alPresionar,
        borderRadius: BorderRadius.circular(8),
        hoverColor: ColoresApp.bgCardHover,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icono,
            size: 20,
            color: deshabilitado
                ? ColoresApp.textDisabled
                : ColoresApp.textSecondary,
          ),
        ),
      ),
    );
  }
}
