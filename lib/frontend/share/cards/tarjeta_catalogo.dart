import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Disposición de [TarjetaCatalogo].
enum OrientacionTarjeta {
  /// Marcador a la izquierda, textos a su derecha y acciones al final.
  /// Para listas de una columna, donde importa recorrer nombres rápido.
  horizontal,

  /// Marcador arriba y textos debajo. Para grillas de varias columnas,
  /// donde cada tarjeta se lee como una unidad.
  vertical,
}

/// Tarjeta de un ítem de catálogo: marcador, nombre, dato secundario y
/// acciones opcionales.
///
/// Pensada para catálogos simples que se leen de un vistazo
/// (especializaciones, categorías, formas de pago), donde una tabla sería
/// demasiado pesada.
///
/// La [orientacion] no solo mueve las piezas: la variante vertical usa las
/// medidas de tarjeta de grilla del diseño (marcador 50, radio 18, título 16)
/// y la horizontal las de fila (marcador 44, radio 16, título 14).
///
/// Parámetros:
/// - [titulo]: nombre del ítem.
/// - [icono]: ícono del marcador. Obligatorio salvo que se pase [marcador].
/// - [marcador]: widget que reemplaza al cuadro de ícono (ej.
///   [MarcadorIdentidad] con la inicial del nombre).
/// - [subtitulo]: dato secundario debajo del título (ej. "3 técnicos").
/// - [acciones]: widget con los botones del ítem (editar, eliminar…).
/// - [pie]: bloque opcional debajo del cuerpo, para los ítems que necesitan
///   más de una línea de datos (el contacto y el teléfono de un proveedor,
///   por ejemplo). Va a ancho completo, así que la grilla que contiene la
///   tarjeta debe reservarle alto.
/// - [orientacion]: disposición de la tarjeta. Por defecto horizontal.
/// - [colorIcono]: color del ícono. Por defecto `ColoresApp.goGreen`.
/// - [colorFondoIcono]: fondo del cuadro. Por defecto `ColoresApp.greenChipBg`.
/// - [alPresionar]: callback opcional al tocar la tarjeta.
/// - [lineasTitulo]: máximo de líneas del título antes de recortar con "…".
///   Por defecto 2, para que los nombres largos bajen de línea en vez de
///   cortarse. La grilla que la contiene debe reservar alto para esas líneas.
///
/// Ejemplo:
/// ```dart
/// TarjetaCatalogo(
///   orientacion: OrientacionTarjeta.vertical,
///   marcador: MarcadorIdentidad(inicial: 'F', color: color, lado: 50, radio: 14),
///   titulo: 'Frenos',
///   subtitulo: '12 productos',
///   acciones: BotonIcono(
///     icono: Icons.edit_outlined,
///     tooltip: 'Editar',
///     alPresionar: () => controlador.editar(item),
///   ),
/// )
/// ```
class TarjetaCatalogo extends StatelessWidget {
  const TarjetaCatalogo({
    super.key,
    required this.titulo,
    this.icono,
    this.marcador,
    this.subtitulo,
    this.acciones,
    this.pie,
    this.orientacion = OrientacionTarjeta.horizontal,
    this.colorIcono,
    this.colorFondoIcono,
    this.alPresionar,
    this.lineasTitulo = 2,
  }) : assert(
          icono != null || marcador != null,
          'TarjetaCatalogo necesita un icono o un marcador',
        );

  final String titulo;
  final IconData? icono;
  final Widget? marcador;
  final String? subtitulo;
  final Widget? acciones;
  final Widget? pie;
  final OrientacionTarjeta orientacion;
  final Color? colorIcono;
  final Color? colorFondoIcono;
  final VoidCallback? alPresionar;
  final int lineasTitulo;

  bool get _esVertical => orientacion == OrientacionTarjeta.vertical;

  @override
  Widget build(BuildContext context) {
    final cuerpo = _esVertical ? _cuerpoVertical() : _cuerpoHorizontal();
    final propio = pie;

    final contenido = Padding(
      padding: EdgeInsets.all(_esVertical ? 22 : 20),
      child: propio == null
          ? cuerpo
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [cuerpo, const SizedBox(height: 15), propio],
            ),
    );

    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(_esVertical ? 18 : 16),
        border: Border.all(color: ColoresApp.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: alPresionar == null
          ? contenido
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: alPresionar,
                hoverColor: ColoresApp.bgCardHover,
                child: contenido,
              ),
            ),
    );
  }

  Widget _cuerpoHorizontal() {
    return Row(
      children: [
        _marcador(lado: 44, radio: 12),
        const SizedBox(width: 13),
        Expanded(child: _textos()),
        ?acciones,
      ],
    );
  }

  Widget _cuerpoVertical() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _marcador(lado: 50, radio: 14),
            const Spacer(),
            // Las acciones se alinean con el marcador para que no bailen
            // cuando el título ocupa una o dos líneas.
            ?acciones,
          ],
        ),
        const SizedBox(height: 16),
        _textos(),
      ],
    );
  }

  Widget _marcador({required double lado, required double radio}) {
    final propio = marcador;
    if (propio != null) return propio;

    return Container(
      width: lado,
      height: lado,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorFondoIcono ?? ColoresApp.greenChipBg,
        borderRadius: BorderRadius.circular(radio),
      ),
      child: Icon(
        icono,
        size: lado * 0.45,
        color: colorIcono ?? ColoresApp.goGreen,
      ),
    );
  }

  Widget _textos() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: _esVertical
              ? TipografiaApp.tituloTarjeta.copyWith(fontSize: 16)
              : TipografiaApp.tituloTarjeta,
          maxLines: lineasTitulo,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
        ),
        if (subtitulo != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitulo!,
            style: TipografiaApp.caption.copyWith(
              fontSize: _esVertical ? 12.5 : 12,
              color: ColoresApp.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
