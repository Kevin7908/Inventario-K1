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
/// **La primera y la última siempre se ven**, con «…» donde haya salto:
/// `1 … 9 10 11 … 20`. Hubo una versión con la ventana contigua y sin elipsis
/// —`9 10 11 12 13`— con el argumento de que un «…» ocupa lo mismo que el
/// número que esconde; el problema es que desde la mitad de una lista larga no
/// había forma de saber **cuántas páginas hay**, y las flechas dobles llevan
/// al final sin decir cuál es. Saber que son veinte es la mitad de para lo que
/// se mira un paginador.
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
/// - [maximoNumeros]: cuántas casillas de página se pintan **cuando hay
///   sitio**, contando los «…» —cada uno ocupa una—. Por defecto 7: los dos
///   extremos, dos elipsis y tres números alrededor de la actual. Con menos
///   ancho se pintan menos, y por debajo de cinco se cae a una ventana
///   contigua, porque los extremos y sus elipsis ya no caben.
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
    this.maximoNumeros = 7,
  });

  final int paginaActual;
  final int totalPaginas;
  final ValueChanged<int> alCambiarPagina;
  final int? totalItems;
  final int? itemsPorPagina;
  final int maximoNumeros;

  // Medidas reales de las piezas, para poder decidir qué cabe sin adivinar.
  static const _anchoNumero = 36.0; // 32 del botón + 2 de padding a cada lado
  static const _anchoFlecha = 32.0;
  static const _anchoRango = 150.0;
  static const _paddingH = 20.0;

  /// Qué casillas se dibujan, en orden. Un `null` es un «…».
  ///
  /// [maximo] son **casillas**, no números: cada elipsis gasta una, así que la
  /// barra mide siempre lo mismo y no baila al navegar.
  ///
  /// La forma es la de siempre en una lista larga: la primera, la última, y
  /// una ventana contigua alrededor de la actual con «…» donde hay salto. Los
  /// tres casos —principio, medio y final— gastan exactamente [maximo]
  /// casillas:
  ///
  /// ```text
  /// 1 2 3 4 5 … 20      cerca del principio
  /// 1 … 9 10 11 … 20    en medio
  /// 1 … 16 17 18 19 20  cerca del final
  /// ```
  ///
  /// Por debajo de cinco casillas los dos extremos y sus dos elipsis no caben
  /// junto a la actual, así que se cae a la ventana contigua de antes: es lo
  /// que pasa en el panel angosto del punto de venta.
  static List<int?> paginasVisibles({
    required int paginaActual,
    required int totalPaginas,
    int maximo = 7,
  }) {
    if (totalPaginas <= 1) return const [0];
    if (maximo <= 0) return const [];
    if (totalPaginas <= maximo) {
      return List<int?>.generate(totalPaginas, (i) => i);
    }

    if (maximo < 5) return _ventanaContigua(paginaActual, totalPaginas, maximo);

    final ultima = totalPaginas - 1;
    // Las casillas que quedan entre la primera y la última.
    final interior = maximo - 2;

    // Cerca del principio: los primeros seguidos, un «…» y la última.
    if (paginaActual <= interior - 2) {
      return [
        for (var i = 0; i < interior; i++) i,
        null,
        ultima,
      ];
    }

    // Cerca del final: la primera, un «…» y los últimos seguidos.
    if (paginaActual >= ultima - (interior - 2)) {
      return [
        0,
        null,
        for (var i = ultima - interior + 1; i <= ultima; i++) i,
      ];
    }

    // En medio: los dos extremos, sus dos elipsis y la ventana entre ellas.
    final centro = interior - 2;
    final inicio = paginaActual - (centro - 1) ~/ 2;
    return [
      0,
      null,
      for (var i = 0; i < centro; i++) inicio + i,
      null,
      ultima,
    ];
  }

  /// La ventana de siempre, sin extremos fijos: para cuando no caben.
  ///
  /// Cerca de los bordes se desplaza en vez de encogerse, para que la barra no
  /// cambie de ancho al navegar.
  static List<int?> _ventanaContigua(int actual, int total, int maximo) {
    final cuantas = maximo < total ? maximo : total;
    var inicio = actual - (cuantas - 1) ~/ 2;

    if (inicio < 0) inicio = 0;
    if (inicio + cuantas > total) inicio = total - cuantas;

    return List<int?>.generate(cuantas, (i) => inicio + i);
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
          var maximo = caben.clamp(0, maximoNumeros);

          // Con uno o dos números la ventana no sirve para navegar —no se
          // puede saltar a ninguna parte— y un «4» suelto no dice de cuántas
          // es. Por debajo de tres se cambia por el contador.
          if (maximo < 3) maximo = 0;

          // El rango se acota a lo que el presupuesto le reservó y los
          // controles se quedan con el resto. Los dos como `Flexible` repartían
          // el ancho en mitades y las flechas no cabían en la suya aunque
          // sobrara sitio al otro lado; los controles sueltos, sin envolver,
          // reciben ancho infinito —un `Row` se lo da a los hijos que no son
          // flexibles— y desbordan por su cuenta. El `Expanded` con `Align` es
          // lo que les da un máximo real.
          return Row(
            children: [
              if (mostrarRango)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _anchoRango),
                  child: Text(
                    _textoRango(),
                    style: TipografiaApp.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Expanded(
                child: Align(
                  alignment: mostrarRango
                      ? Alignment.centerRight
                      : Alignment.center,
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
            if (pagina == null)
              const _Elipsis()
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

/// El salto entre dos tramos de páginas.
///
/// Mide **lo mismo que un número** a propósito: así el presupuesto de ancho
/// que reparte `PaginacionWidget` cuadra casilla por casilla y la barra no
/// cambia de largo al pasar de página. Sin borde ni tinta fuerte, porque no se
/// puede pulsar: lo que hay ahí son las páginas que las flechas alcanzan.
class _Elipsis extends StatelessWidget {
  const _Elipsis();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Text(
            '…',
            style: TextStyle(
              fontSize: 15,
              height: 1,
              color: ColoresApp.textDisabled,
            ),
          ),
        ),
      ),
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
