import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Navegación entre páginas de una colección paginada.
///
/// Muestra números de página, no solo «anterior/siguiente»: desde la mitad de
/// una lista larga se puede saltar dos o tres páginas de golpe, o ir directo a
/// la primera o la última, sin pulsar la flecha muchas veces.
///
/// **Se adapta al ancho que le den.** Es la misma barra en la pantalla de
/// Productos a pantalla completa que en el panel de 300 px del punto de venta,
/// y por eso va midiendo qué cabe y soltando piezas por orden de importancia:
/// primero el rango («Mostrando 1–20 de 97»), después los saltos a los
/// extremos, después los números —que se reducen de a uno— y en el último
/// tramo se queda con dos flechas y un «4 / 12». Nunca desborda, que es lo que
/// pasaba antes cuando la ventana se hacía angosta.
///
/// **Sin elipsis.** La ventana de páginas es contigua: se corre alrededor de
/// la actual en vez de fijar la primera y la última con «…» en medio. Un «…»
/// ocupa lo mismo que el número que esconde y no se puede pulsar, y las
/// flechas dobles ya llevan a los extremos.
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
///   [itemsPorPagina], se muestra el rango cuando hay ancho para él.
/// - [itemsPorPagina]: tamaño de página usado para calcular el rango mostrado.
/// - [radio]: cuántas páginas se ven a cada lado de la actual **cuando hay
///   sitio**. Por defecto 2, o sea una ventana de cinco; con menos ancho se
///   muestran menos.
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

  // Medidas reales de las piezas, para poder decidir qué cabe sin adivinar.
  static const _anchoNumero = 36.0; // 32 del botón + 2 de padding a cada lado
  static const _anchoFlecha = 32.0;
  static const _anchoRango = 150.0;
  static const _paddingH = 20.0;

  /// Qué páginas se dibujan: una ventana **contigua** de a lo sumo [maximo]
  /// números alrededor de [paginaActual].
  ///
  /// Cerca de los bordes la ventana se desplaza en vez de encogerse, para que
  /// la barra no cambie de ancho al navegar. Nunca devuelve huecos: si no
  /// caben todas las páginas, las que faltan se alcanzan con las flechas.
  static List<int> paginasVisibles({
    required int paginaActual,
    required int totalPaginas,
    int maximo = 5,
  }) {
    if (totalPaginas <= 1) return const [0];
    if (maximo <= 0) return const [];

    final cuantas = maximo < totalPaginas ? maximo : totalPaginas;
    var inicio = paginaActual - (cuantas - 1) ~/ 2;

    // Apoyar la ventana en el borde que toque, sin salirse por ninguno.
    if (inicio < 0) inicio = 0;
    if (inicio + cuantas > totalPaginas) inicio = totalPaginas - cuantas;

    return List<int>.generate(cuantas, (i) => inicio + i);
  }

  @override
  Widget build(BuildContext context) {
    final paginas = totalPaginas < 1 ? 1 : totalPaginas;
    final hayAnterior = paginaActual > 0;
    final haySiguiente = paginaActual < paginas - 1;
    final hayRango = totalItems != null && itemsPorPagina != null;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: _paddingH, vertical: 14),
      child: LayoutBuilder(
        builder: (context, restricciones) {
          // `maxWidth` puede llegar infinito si el padre no acota; en ese caso
          // se asume holgura y se pinta la barra completa.
          final ancho = restricciones.maxWidth.isFinite
              ? restricciones.maxWidth
              : double.maxFinite;

          final mostrarRango = hayRango && ancho >= 560;
          final mostrarExtremos = ancho >= 420;

          var libre = ancho;
          if (mostrarRango) libre -= _anchoRango;
          libre -= _anchoFlecha * 2; // anterior y siguiente, siempre
          if (mostrarExtremos) libre -= _anchoFlecha * 2;
          libre -= 16; // los dos separadores de 4 y un respiro

          final caben = (libre / _anchoNumero).floor();
          var maximo = caben.clamp(0, radio * 2 + 1);

          // Con uno o dos números la ventana no sirve para navegar —no se
          // puede saltar a ninguna parte— y un «4» suelto no dice de cuántas
          // es. Por debajo de tres se cambia por el contador.
          if (maximo < 3) maximo = 0;

          return Row(
            mainAxisAlignment: mostrarRango
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.center,
            children: [
              if (mostrarRango)
                Flexible(
                  child: Text(
                    _textoRango(),
                    style: TipografiaApp.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Flexible(
                child: _Controles(
                  paginaActual: paginaActual,
                  totalPaginas: paginas,
                  maximoNumeros: maximo,
                  mostrarExtremos: mostrarExtremos,
                  hayAnterior: hayAnterior,
                  haySiguiente: haySiguiente,
                  alCambiarPagina: alCambiarPagina,
                ),
              ),
            ],
          );
        },
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

/// Las flechas y los números. Aparte para que el `LayoutBuilder` decida qué
/// pasarle y este solo pinte.
class _Controles extends StatelessWidget {
  const _Controles({
    required this.paginaActual,
    required this.totalPaginas,
    required this.maximoNumeros,
    required this.mostrarExtremos,
    required this.hayAnterior,
    required this.haySiguiente,
    required this.alCambiarPagina,
  });

  final int paginaActual;
  final int totalPaginas;
  final int maximoNumeros;
  final bool mostrarExtremos;
  final bool hayAnterior;
  final bool haySiguiente;
  final ValueChanged<int> alCambiarPagina;

  @override
  Widget build(BuildContext context) {
    final numeros = PaginacionWidget.paginasVisibles(
      paginaActual: paginaActual,
      totalPaginas: totalPaginas,
      maximo: maximoNumeros,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (mostrarExtremos)
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
        // Sin sitio ni para un número, la barra se queda con lo mínimo que
        // sigue siendo útil: dónde estoy y de cuántas.
        if (numeros.isEmpty)
          // Sin espacios alrededor de la barra: «6/20» mide 20 px menos que
          // «6 / 20», y son justo los que faltaban en el panel más angosto.
          // Y `Flexible` con elipsis para que, pase lo que pase con el ancho,
          // la barra se encoja en vez de desbordar.
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '${paginaActual + 1}/$totalPaginas',
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TipografiaApp.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: ColoresApp.textSecondary,
                ),
              ),
            ),
          )
        else
          for (final pagina in numeros)
            _NumeroPagina(
              numero: pagina,
              activa: pagina == paginaActual,
              alPresionar: () => alCambiarPagina(pagina),
            ),
        const SizedBox(width: 4),
        _BotonFlecha(
          icono: Icons.chevron_right_rounded,
          tooltip: 'Siguiente',
          alPresionar:
              haySiguiente ? () => alCambiarPagina(paginaActual + 1) : null,
        ),
        if (mostrarExtremos)
          _BotonFlecha(
            icono: Icons.keyboard_double_arrow_right_rounded,
            tooltip: 'Última página',
            alPresionar:
                haySiguiente ? () => alCambiarPagina(totalPaginas - 1) : null,
          ),
      ],
    );
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
