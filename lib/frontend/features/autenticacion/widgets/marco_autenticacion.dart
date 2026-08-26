import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../share2/share2.dart';
import 'ilustracion/ilustracion_gatos.dart';

/// Radio de la tarjeta. Lo comparten el contenedor y el panel de la
/// ilustración, que redondea solo su lado izquierdo para no salirse.
const double _radioTarjeta = 20;

/// El marco visual que comparten el login, el alta del primer administrador y
/// la recuperación de la contraseña.
///
/// Son tres pantallas con el mismo esqueleto: una tarjeta blanca flotando
/// sobre el fondo oscuro de la marca —el mismo `bgSidebar` del sidebar, para
/// que entrar no parezca otro programa—, partida en dos: a la izquierda la
/// ilustración del taller, a la derecha el formulario. Cuando la ventana no da
/// para las dos mitades, la ilustración se va y queda la tarjeta del
/// formulario sola.
///
/// Vive en el módulo y no en `share2` porque solo lo usan estas tres
/// pantallas y porque conoce el logo y la ilustración de la app.
///
/// Parámetros:
/// - [titulo] y [subtitulo]: encabezan el formulario, centrados.
/// - [child]: el formulario.
/// - [alVolver]: si se pasa, aparece la flecha de regreso sobre el título.
/// - [etiquetaVolver]: texto de esa flecha.
///
/// Ejemplo:
/// ```dart
/// MarcoAutenticacion(
///   titulo: 'Bienvenido de nuevo',
///   subtitulo: 'Escribe tus datos para entrar.',
///   child: _FormularioLogin(),
/// )
/// ```
class MarcoAutenticacion extends StatelessWidget {
  const MarcoAutenticacion({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.child,
    this.alVolver,
    this.etiquetaVolver = 'Volver',
  });

  static const double _anchoIlustracion = 440;
  static const double _anchoFormulario = 460;
  static const double _altoTarjeta = 620;
  static const double _margenVentana = 32;

  /// Por debajo de esto la tarjeta partida no cabe sin apretar el formulario,
  /// así que la ilustración se va antes que estorbar.
  static const double _anchoMinimoConPanel = 940;
  static const double _altoMinimoConPanel = 560;

  final String titulo;
  final String subtitulo;
  final Widget child;
  final VoidCallback? alVolver;
  final String etiquetaVolver;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.bgSidebar,
      body: LayoutBuilder(
        builder: (context, restricciones) {
          final cabePanel = restricciones.maxWidth >= _anchoMinimoConPanel &&
              restricciones.maxHeight >= _altoMinimoConPanel;

          // La tarjeta nunca pasa del alto de la ventana: si sobra contenido
          // —el alta del primer administrador son cinco campos— scrollea por
          // dentro y el marco se queda quieto.
          final alto = math.max(
            0.0,
            math.min(_altoTarjeta, restricciones.maxHeight - _margenVentana * 2),
          );

          final formulario = _Formulario(
            titulo: titulo,
            subtitulo: subtitulo,
            alVolver: alVolver,
            etiquetaVolver: etiquetaVolver,
            child: child,
          );

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(_margenVentana),
              child: Container(
                width: cabePanel
                    ? _anchoIlustracion + _anchoFormulario
                    : _anchoFormulario,
                height: cabePanel ? alto : null,
                constraints:
                    cabePanel ? null : BoxConstraints(maxHeight: alto),
                decoration: const BoxDecoration(
                  color: ColoresApp.bgCard,
                  borderRadius: BorderRadius.all(
                    Radius.circular(_radioTarjeta),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ColoresApp.shadowMedium,
                      blurRadius: 40,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: cabePanel
                    ? Row(
                        // La Row está dentro de una altura fija, que es lo que
                        // `stretch` necesita para no reventar (`CLAUDE.md` §4).
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(
                            width: _anchoIlustracion,
                            child: _PanelIlustracion(),
                          ),
                          Expanded(child: formulario),
                        ],
                      )
                    : formulario,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// La mitad derecha de la tarjeta: marca, título centrado y el formulario.
class _Formulario extends StatelessWidget {
  const _Formulario({
    required this.titulo,
    required this.subtitulo,
    required this.alVolver,
    required this.etiquetaVolver,
    required this.child,
  });

  final String titulo;
  final String subtitulo;
  final VoidCallback? alVolver;
  final String etiquetaVolver;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(44, 40, 44, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (alVolver != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: BotonVolver(
                etiqueta: etiquetaVolver,
                alPresionar: alVolver!,
              ),
            ),
            const SizedBox(height: 16),
          ],
          const _MarcaCompacta(),
          const SizedBox(height: 24),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: TipografiaApp.heading1,
          ),
          const SizedBox(height: 8),
          Text(
            subtitulo,
            textAlign: TextAlign.center,
            style: TipografiaApp.subtituloPagina,
          ),
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
  }
}

/// El logo y el nombre, centrados sobre el título. La ilustración no lleva
/// marca, así que la marca va aquí y se ve con panel y sin él.
class _MarcaCompacta extends StatelessWidget {
  const _MarcaCompacta();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset('assets/images/logo-k1.svg', width: 32, height: 32),
        const SizedBox(width: 10),
        Text(
          'InventarioK1',
          style: TipografiaApp.subtitulo.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// La mitad izquierda: la ilustración del taller sobre el gris de la app.
class _PanelIlustracion extends StatelessWidget {
  const _PanelIlustracion();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: ColoresApp.bgApp,
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(_radioTarjeta),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(40, 40, 40, 32),
        child: Column(
          children: [
            Expanded(child: IlustracionGatos()),
            SizedBox(height: 24),
            Text(
              'Todo el taller en un solo sitio.',
              textAlign: TextAlign.center,
              style: TipografiaApp.subtitulo,
            ),
            SizedBox(height: 6),
            Text(
              'Los datos se guardan en este equipo.',
              textAlign: TextAlign.center,
              style: TipografiaApp.caption,
            ),
          ],
        ),
      ),
    );
  }
}
