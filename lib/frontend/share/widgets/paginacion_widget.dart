import 'package:flutter/material.dart';
import '../temas/colores_app.dart';

/// Widget de paginación reutilizable para cualquier lista.
/// [paginaActual] es 0-indexed.
class PaginacionWidget extends StatelessWidget {
  const PaginacionWidget({
    super.key,
    required this.paginaActual,
    required this.totalPaginas,
    required this.totalItems,
    required this.itemsPorPagina,
    required this.alCambiarPagina,
    this.labelEntidad = 'elementos',
  });

  final int paginaActual;
  final int totalPaginas;
  final int totalItems;
  final int itemsPorPagina;
  final ValueChanged<int> alCambiarPagina;

  /// Ej: 'cotizaciones', 'productos', 'órdenes'
  final String labelEntidad;

  int get _inicio => totalItems == 0 ? 0 : paginaActual * itemsPorPagina + 1;
  int get _fin => ((paginaActual + 1) * itemsPorPagina).clamp(0, totalItems);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: ColoresApp.bgCard,
        border: Border(top: BorderSide(color: ColoresApp.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            totalItems == 0
                ? 'Sin $labelEntidad'
                : 'Mostrando $_inicio–$_fin de $totalItems $labelEntidad',
            style: const TextStyle(
              color: ColoresApp.textMedium,
              fontSize: 13,
            ),
          ),
          _BotonesPagina(
            paginaActual: paginaActual,
            totalPaginas: totalPaginas,
            alCambiarPagina: alCambiarPagina,
          ),
        ],
      ),
    );
  }
}

class _BotonesPagina extends StatelessWidget {
  const _BotonesPagina({
    required this.paginaActual,
    required this.totalPaginas,
    required this.alCambiarPagina,
  });

  final int paginaActual;
  final int totalPaginas;
  final ValueChanged<int> alCambiarPagina;

  List<int> get _paginas {
    if (totalPaginas <= 5) {
      return List.generate(totalPaginas, (i) => i);
    }
    // Ventana deslizante de 5 páginas alrededor de la actual
    var inicio = (paginaActual - 2).clamp(0, totalPaginas - 5);
    return List.generate(5, (i) => inicio + i);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _NavBtn(
          icono: Icons.chevron_left_rounded,
          habilitado: paginaActual > 0,
          onTap: () => alCambiarPagina(paginaActual - 1),
        ),
        const SizedBox(width: 4),
        for (final p in _paginas) ...[
          _NumBtn(
            numero: p + 1,
            seleccionado: p == paginaActual,
            onTap: () => alCambiarPagina(p),
          ),
          const SizedBox(width: 4),
        ],
        _NavBtn(
          icono: Icons.chevron_right_rounded,
          habilitado: paginaActual < totalPaginas - 1,
          onTap: () => alCambiarPagina(paginaActual + 1),
        ),
      ],
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({
    required this.icono,
    required this.habilitado,
    required this.onTap,
  });

  final IconData icono;
  final bool habilitado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: habilitado ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: ColoresApp.bgContent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ColoresApp.border),
        ),
        child: Icon(
          icono,
          size: 18,
          color: habilitado ? ColoresApp.textMedium : ColoresApp.textLight,
        ),
      ),
    );
  }
}

class _NumBtn extends StatelessWidget {
  const _NumBtn({
    required this.numero,
    required this.seleccionado,
    required this.onTap,
  });

  final int numero;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: seleccionado ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: seleccionado ? ColoresApp.primary : ColoresApp.bgContent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: seleccionado ? ColoresApp.primary : ColoresApp.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '$numero',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: seleccionado ? Colors.white : ColoresApp.textMedium,
          ),
        ),
      ),
    );
  }
}
