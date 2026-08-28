import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Navegación entre páginas de una colección paginada.
///
/// Muestra números de página, no solo "anterior/siguiente": desde la mitad de
/// una lista larga se puede saltar dos o tres páginas de golpe, o ir directo a
/// la primera o la última, sin pulsar la flecha muchas veces.
///
/// Se combina con [TablaGenerica] pasándole solo los ítems de la página
/// actual, de forma que la tabla nunca construye más filas de las que caben en
/// una página.
///
/// Parámetros:
/// - [paginaActual]: índice 0-based de la página mostrada.
/// - [totalPaginas]: cantidad total de páginas (mínimo 1).
/// - [alCambiarPagina]: callback que recibe el nuevo índice de página.
/// - [totalItems]: total de ítems sin paginar. Si se define junto con
///   [itemsPorPagina], se muestra el rango ("Mostrando 1–20 de 97").
/// - [itemsPorPagina]: tamaño de página usado para calcular el rango mostrado.
/// - [radio]: cuántas páginas se ven a cada lado de la actual. Por defecto 2,
///   o sea una ventana de cinco.
///
/// Ejemplo:
/// ```dart
/// Column(
///   children: [
///     Expanded(child: TablaGenerica(items: pagina.items, columnas: columnas)),
///     PaginacionWidget(
///       paginaActual: estado.pagina,
///       totalPaginas: estado.totalPaginas,
///       totalItems: estado.total,
///       itemsPorPagina: estado.tamanoPagina,
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
    this.radio = 2,
  });

  final int paginaActual;
  final int totalPaginas;
  final ValueChanged<int> alCambiarPagina;
  final int? totalItems;
  final int? itemsPorPagina;
  final int radio;

  /// Qué páginas se dibujan. Un `null` es un salto ("…").
  ///
  /// Siempre incluye la primera y la última, más una ventana de [radio]
  /// páginas a cada lado de [paginaActual]. Cerca de los bordes la ventana se
  /// desplaza en vez de encogerse, para que la barra no cambie de ancho al
  /// navegar.
  static List<int?> paginasVisibles({
    required int paginaActual,
    required int totalPaginas,
    int radio = 2,
  }) {
    if (totalPaginas <= 1) return const [0];

    // Primera, última, dos elipsis y la ventana: por debajo de eso caben todas
    // y poner "…" ocuparía lo mismo que el número que esconde.
    final sinCortes = radio * 2 + 5;
    if (totalPaginas <= sinCortes) {
      return List<int?>.generate(totalPaginas, (i) => i);
    }

    final ultima = totalPaginas - 1;
    var inicio = paginaActual - radio;
    var fin = paginaActual + radio;

    if (inicio < 1) {
      fin += 1 - inicio;
      inicio = 1;
    }
    if (fin > ultima - 1) {
      inicio -= fin - (ultima - 1);
      fin = ultima - 1;
    }
    inicio = inicio.clamp(1, ultima - 1);
    fin = fin.clamp(1, ultima - 1);

    return <int?>[
      0,
      if (inicio > 1) null,
      for (var i = inicio; i <= fin; i++) i,
      if (fin < ultima - 1) null,
      ultima,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final paginas = totalPaginas < 1 ? 1 : totalPaginas;
    final hayAnterior = paginaActual > 0;
    final haySiguiente = paginaActual < paginas - 1;

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
            mainAxisSize: MainAxisSize.min,
            children: [
              _BotonFlecha(
                icono: Icons.keyboard_double_arrow_left_rounded,
                tooltip: 'Primera página',
                alPresionar: hayAnterior ? () => alCambiarPagina(0) : null,
              ),
              _BotonFlecha(
                icono: Icons.chevron_left_rounded,
                tooltip: 'Anterior',
                alPresionar:
                    hayAnterior ? () => alCambiarPagina(paginaActual - 1) : null,
              ),
              const SizedBox(width: 4),
              for (final pagina in paginasVisibles(
                paginaActual: paginaActual,
                totalPaginas: paginas,
                radio: radio,
              ))
                if (pagina == null)
                  const _Salto()
                else
                  _NumeroPagina(
                    numero: pagina,
                    activa: pagina == paginaActual,
                    alPresionar: () => alCambiarPagina(pagina),
                  ),
              const SizedBox(width: 4),
              _BotonFlecha(
                icono: Icons.chevron_right_rounded,
                tooltip: 'Siguiente',
                alPresionar: haySiguiente
                    ? () => alCambiarPagina(paginaActual + 1)
                    : null,
              ),
              _BotonFlecha(
                icono: Icons.keyboard_double_arrow_right_rounded,
                tooltip: 'Última página',
                alPresionar:
                    haySiguiente ? () => alCambiarPagina(paginas - 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _textoRango() {
    final total = totalItems!;
    if (total <= 0) return 'Mostrando 0 de 0';

    final porPagina = itemsPorPagina!;
    final inicio = paginaActual * porPagina + 1;
    final fin = (inicio + porPagina - 1).clamp(0, total);
    return 'Mostrando $inicio–$fin de $total';
  }
}

/// Número de página. La activa va en verde de marca, como los chips.
class _NumeroPagina extends StatelessWidget {
  const _NumeroPagina({
    required this.numero,
    required this.activa,
    required this.alPresionar,
  });

  final int numero;
  final bool activa;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: activa ? ColoresApp.goGreen : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: activa ? null : alPresionar,
          hoverColor: activa ? Colors.transparent : ColoresApp.bgCardHover,
          child: Container(
            constraints: const BoxConstraints(minWidth: 32),
            height: 32,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: activa ? ColoresApp.goGreen : ColoresApp.border,
              ),
            ),
            child: Text(
              '${numero + 1}',
              style: TipografiaApp.caption.copyWith(
                fontWeight: FontWeight.w600,
                color:
                    activa ? ColoresApp.textOnPrimary : ColoresApp.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Marca de páginas omitidas. No es pulsable a propósito: las flechas dobles
/// ya llevan a los extremos y un "…" que salta a un número arbitrario confunde.
class _Salto extends StatelessWidget {
  const _Salto();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 32,
      child: Center(
        child: Text(
          '…',
          style: TipografiaApp.caption.copyWith(color: ColoresApp.textDisabled),
        ),
      ),
    );
  }
}

class _BotonFlecha extends StatelessWidget {
  const _BotonFlecha({
    required this.icono,
    required this.tooltip,
    required this.alPresionar,
  });

  final IconData icono;
  final String tooltip;
  final VoidCallback? alPresionar;

  @override
  Widget build(BuildContext context) {
    final deshabilitado = alPresionar == null;

    final boton = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPresionar,
        hoverColor: ColoresApp.bgCardHover,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icono,
            size: 19,
            color: deshabilitado
                ? ColoresApp.textDisabled
                : ColoresApp.textSecondary,
          ),
        ),
      ),
    );

    // Sin tooltip cuando está deshabilitado: no hay acción que describir.
    return deshabilitado ? boton : Tooltip(message: tooltip, child: boton);
  }
}
