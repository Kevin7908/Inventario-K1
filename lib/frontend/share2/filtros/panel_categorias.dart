import 'package:flutter/material.dart';

import '../cards/marcador_identidad.dart';
import '../inputs/barra_busqueda.dart';
import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';
import 'categoria_panel_dato.dart';

/// Panel lateral colapsable para filtrar una lista por categoría.
///
/// Reemplaza a una fila de [ChipFiltro] cuando hay tantas categorías que los
/// chips desbordan: la lista vive en una columna con buscador propio, y el
/// panel se contrae a una tira de íconos para devolver el ancho al contenido.
///
/// Como todo `share2`, no decide nada: recibe [categorias] **ya filtradas**
/// por el texto de búsqueda, [seleccionada] ya resuelta y [expandido] como
/// estado del módulo; avisa por callbacks.
///
/// Parámetros:
/// - [categorias]: categorías a listar, en el orden en que se pintan.
/// - [seleccionada]: id de la categoría activa. `null` = "todas".
/// - [alSeleccionar]: se llama con el id elegido, o `null` al pulsar "todas".
/// - [expandido]: si el panel muestra la columna completa o la tira de íconos.
/// - [alAlternar]: se llama al pulsar el control de contraer/expandir.
/// - [controladorBusqueda]: controla el buscador de la cabecera. Si es `null`,
///   el buscador no se dibuja.
/// - [alBuscar]: callback en cada cambio del buscador.
/// - [titulo]: encabezado del panel. Por defecto `'Categorías'`.
/// - [etiquetaTodas]: texto del ítem que limpia el filtro.
/// - [expandidas]: ids cuyas [CategoriaPanelDato.subcategorias] están abiertas.
/// - [alAlternarSubcategorias]: se llama con el id al pulsar su control de
///   despliegue. Si es `null`, las subcategorías no se pueden abrir.
/// - [anchoExpandido] / [anchoContraido]: anchos del panel en cada estado.
///
/// Ejemplo:
/// ```dart
/// PanelCategorias(
///   categorias: categorias,
///   seleccionada: estado.filtroCategoriaId,
///   alSeleccionar: (id) => controlador.filtrarPorCategoria(id),
///   expandido: _panelExpandido,
///   alAlternar: () => setState(() => _panelExpandido = !_panelExpandido),
///   controladorBusqueda: _busquedaCategoriaController,
///   alBuscar: (texto) => setState(() => _busquedaCategoria = texto),
/// )
/// ```
class PanelCategorias extends StatelessWidget {
  const PanelCategorias({
    super.key,
    required this.categorias,
    required this.seleccionada,
    required this.alSeleccionar,
    required this.expandido,
    required this.alAlternar,
    this.controladorBusqueda,
    this.alBuscar,
    this.titulo = 'Categorías',
    this.etiquetaTodas = 'Todas',
    this.expandidas = const {},
    this.alAlternarSubcategorias,
    this.anchoExpandido = 208,
    this.anchoContraido = 52,
  });

  final List<CategoriaPanelDato> categorias;
  final int? seleccionada;
  final ValueChanged<int?> alSeleccionar;
  final bool expandido;
  final VoidCallback alAlternar;
  final TextEditingController? controladorBusqueda;
  final ValueChanged<String>? alBuscar;
  final String titulo;
  final String etiquetaTodas;
  final Set<int> expandidas;
  final ValueChanged<int>? alAlternarSubcategorias;
  final double anchoExpandido;
  final double anchoContraido;

  @override
  Widget build(BuildContext context) {
    final ancho = expandido ? anchoExpandido : anchoContraido;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.ease,
      width: ancho,
      decoration: const BoxDecoration(
        color: ColoresApp.bgInput,
        border: Border(right: BorderSide(color: ColoresApp.border)),
      ),
      // Durante la animación el ancho del contenedor va cambiando; el
      // contenido se mantiene en su ancho final y se recorta, para que no
      // desborde a mitad de camino.
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: ancho,
          maxWidth: ancho,
          child: expandido ? _columna() : _tira(),
        ),
      ),
    );
  }

  // Panel abierto: encabezado + buscador + lista con nombres.
  Widget _columna() {
    final controlador = controladorBusqueda;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: TipografiaApp.overline.copyWith(
                    color: ColoresApp.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _BotonAlternar(
                icono: Icons.chevron_left_rounded,
                tooltip: 'Contraer categorías',
                alPresionar: alAlternar,
              ),
            ],
          ),
        ),
        if (controlador != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: BarraBusqueda(
              controlador: controlador,
              placeholder: 'Buscar',
              alCambiar: alBuscar,
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
            children: [
              _FilaCategoria(
                etiqueta: etiquetaTodas,
                icono: Icons.grid_view_rounded,
                activa: seleccionada == null,
                alPresionar: () => alSeleccionar(null),
              ),
              for (final categoria in categorias) ...[
                _FilaCategoria(
                  etiqueta: categoria.nombre,
                  icono: categoria.icono,
                  inicial: categoria.inicial,
                  color: categoria.color,
                  activa: seleccionada == categoria.id,
                  alPresionar: () => alSeleccionar(categoria.id),
                  desplegada: expandidas.contains(categoria.id),
                  alDesplegar: categoria.subcategorias.isEmpty ||
                          alAlternarSubcategorias == null
                      ? null
                      : () => alAlternarSubcategorias!(categoria.id),
                ),
                if (expandidas.contains(categoria.id))
                  for (final sub in categoria.subcategorias)
                    Padding(
                      padding: const EdgeInsets.only(left: 30, bottom: 2),
                      child: Text(
                        sub,
                        style: TipografiaApp.caption.copyWith(
                          fontSize: 11.5,
                          color: ColoresApp.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Panel contraído: solo marcadores, con el nombre en el tooltip.
  Widget _tira() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: _BotonAlternar(
            icono: Icons.chevron_right_rounded,
            tooltip: 'Expandir categorías',
            alPresionar: alAlternar,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 14),
            children: [
              _MarcadorCategoria(
                etiqueta: etiquetaTodas,
                icono: Icons.grid_view_rounded,
                activa: seleccionada == null,
                alPresionar: () => alSeleccionar(null),
              ),
              for (final categoria in categorias)
                _MarcadorCategoria(
                  etiqueta: categoria.nombre,
                  icono: categoria.icono,
                  inicial: categoria.inicial,
                  color: categoria.color,
                  activa: seleccionada == categoria.id,
                  alPresionar: () => alSeleccionar(categoria.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Control de contraer/expandir: un chevron discreto con área táctil cómoda.
class _BotonAlternar extends StatelessWidget {
  const _BotonAlternar({
    required this.icono,
    required this.tooltip,
    required this.alPresionar,
  });

  final IconData icono;
  final String tooltip;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alPresionar,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(icono, size: 18, color: ColoresApp.textMuted),
          ),
        ),
      ),
    );
  }
}

/// Fila de la lista abierta: marcador + nombre (+ control de subcategorías).
class _FilaCategoria extends StatelessWidget {
  const _FilaCategoria({
    required this.etiqueta,
    required this.activa,
    required this.alPresionar,
    this.icono,
    this.inicial,
    this.color,
    this.desplegada = false,
    this.alDesplegar,
  });

  final String etiqueta;
  final bool activa;
  final VoidCallback alPresionar;
  final IconData? icono;
  final String? inicial;
  final Color? color;
  final bool desplegada;
  final VoidCallback? alDesplegar;

  @override
  Widget build(BuildContext context) {
    final estilo = TipografiaApp.caption.copyWith(
      fontWeight: activa ? FontWeight.w600 : FontWeight.w500,
      color: activa ? ColoresApp.castletonGreen : ColoresApp.textPrimary,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: activa ? ColoresApp.greenChipBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alPresionar,
          hoverColor: activa ? Colors.transparent : ColoresApp.bgCardHover,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(7, 6, 4, 6),
            child: Row(
              children: [
                _marcador(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    etiqueta,
                    style: estilo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (alDesplegar != null)
                  InkWell(
                    onTap: alDesplegar,
                    borderRadius: BorderRadius.circular(4),
                    child: Icon(
                      desplegada
                          ? Icons.expand_more_rounded
                          : Icons.chevron_right_rounded,
                      size: 16,
                      color: ColoresApp.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// El ícono va suelto y solo la inicial se enmarca: en la tira contraída un
  /// recuadro alrededor de cada ícono se leería como un botón.
  Widget _marcador() {
    final acento = color ?? (activa ? ColoresApp.goGreen : ColoresApp.textMuted);
    final propio = icono;
    if (propio != null) return Icon(propio, size: 16, color: acento);

    return MarcadorIdentidad(
      inicial: inicial,
      color: acento,
      lado: 18,
      radio: 5,
      tamanoContenido: 10,
    );
  }
}

/// Ítem del panel contraído: solo el marcador, con tooltip.
class _MarcadorCategoria extends StatelessWidget {
  const _MarcadorCategoria({
    required this.etiqueta,
    required this.activa,
    required this.alPresionar,
    this.icono,
    this.inicial,
    this.color,
  });

  final String etiqueta;
  final bool activa;
  final VoidCallback alPresionar;
  final IconData? icono;
  final String? inicial;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: etiqueta,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Material(
          color: activa ? ColoresApp.greenChipBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: alPresionar,
            hoverColor: activa ? Colors.transparent : ColoresApp.bgCardHover,
            child: SizedBox(
              height: 32,
              child: Center(
                child: _marcador(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// El ícono va suelto y solo la inicial se enmarca: en la tira contraída un
  /// recuadro alrededor de cada ícono se leería como un botón.
  Widget _marcador() {
    final acento = color ?? (activa ? ColoresApp.goGreen : ColoresApp.textMuted);
    final propio = icono;
    if (propio != null) return Icon(propio, size: 16, color: acento);

    return MarcadorIdentidad(
      inicial: inicial,
      color: acento,
      lado: 18,
      radio: 5,
      tamanoContenido: 10,
    );
  }
}
