import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'ojos_gato.dart';

/// La ilustración de la pantalla de entrada: Zimba y Timón, moviéndose.
///
/// El SVG original traía su animación en SMIL y `flutter_svg` no la reproduce
/// —avisaba con `unhandled element <animateTransform/>` en cada arranque—, así
/// que el dibujo está partido en capas quietas (`assets/images/gatos/`) y el
/// movimiento lo pone Flutter encima: respiración, colas, balanceo de los dos
/// gatos y de sus cabezas, parpadeos y pupilas.
///
/// Todo se mueve con **un solo `AnimationController`** que da una vuelta de 60
/// segundos. Cada pieza saca su fase de ese reloj con su propio periodo, y los
/// periodos dividen exactamente a 60: al reiniciar la vuelta no hay salto.
///
/// Con «reducir movimiento» activado en el sistema el reloj no arranca y el
/// dibujo se queda quieto. Es un adorno: quien pidió que nada se moviera no
/// tiene por qué pelearse con dos gatos para leer el formulario.
///
/// Ejemplo:
/// ```dart
/// const SizedBox(width: 360, child: IlustracionGatos())
/// ```
class IlustracionGatos extends StatefulWidget {
  const IlustracionGatos({super.key});

  @override
  State<IlustracionGatos> createState() => _IlustracionGatosState();
}

class _IlustracionGatosState extends State<IlustracionGatos>
    with SingleTickerProviderStateMixin {
  /// Una vuelta del reloj. Es múltiplo de todos los periodos de la escena, así
  /// que al reiniciarse ninguna pieza da un salto.
  static const int _segundosPorVuelta = 60;

  late final AnimationController _reloj = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _segundosPorVuelta),
  );

  /// Arrancar aquí y no al crear el controlador: `MediaQuery` no se puede
  /// consultar antes, y es quien dice si el sistema pidió no mover nada.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (MediaQuery.disableAnimationsOf(context)) {
      _reloj.stop();
    } else if (!_reloj.isAnimating) {
      _reloj.repeat();
    }
  }

  @override
  void dispose() {
    _reloj.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // La ilustración se repinta sola sesenta veces por segundo y no la mira
    // nadie más: sin este límite arrastraría a repintar la tarjeta entera.
    return RepaintBoundary(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _Escena.ancho,
          height: _Escena.alto,
          child: AnimatedBuilder(
            animation: _reloj,
            builder: (_, _) => _Escena(t: _reloj.value * _segundosPorVuelta),
          ),
        ),
      ),
    );
  }
}

/// Un fotograma de la ilustración, en el sistema de coordenadas del SVG.
///
/// Es `StatelessWidget` y no un método: así las capas de dentro son `const` y
/// Flutter corta el rebuild ahí. Lo único que cambia entre fotogramas son las
/// matrices de los `Transform`, que es barato.
class _Escena extends StatelessWidget {
  const _Escena({required this.t});

  static const double ancho = 480;
  static const double alto = 408;

  /// Segundos transcurridos dentro de la vuelta del reloj.
  final double t;

  /// Una oscilación suave de −1 a 1 con el periodo pedido, en segundos.
  static double _oscila(double t, double periodo) =>
      math.sin(2 * math.pi * t / periodo);

  /// 1 con el ojo abierto, casi 0 en el instante del parpadeo.
  ///
  /// [desfase] separa el parpadeo de los dos gatos: si coincidiera, parecerían
  /// la misma marioneta.
  static double _apertura(double t, double periodo, double desfase) {
    final fase = ((t + desfase) % periodo) / periodo;
    const duracionParpadeo = 0.022;
    if (fase > duracionParpadeo) return 1;
    return math.max(0.06, 1 - math.sin(math.pi * fase / duracionParpadeo));
  }

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      // Respiración del conjunto, apoyada en el suelo del dibujo.
      scale: 1 + 0.0065 * (1 + _oscila(t, 4)),
      origin: const Offset(240, 400),
      alignment: Alignment.topLeft,
      child: Stack(
        children: [
          const _Capa('fondo'),
          _Burbujas(t: t),
          _Giro(
            grados: 8 * _oscila(t, 3),
            pivote: const Offset(92, 330),
            child: const _Capa('cola_naranja'),
          ),
          _Giro(
            grados: -7 * _oscila(t, 2.5),
            pivote: const Offset(424, 322),
            child: const _Capa('cola_negra'),
          ),
          _Giro(
            grados: 6 + 0.75 + 0.75 * _oscila(t, 5),
            pivote: const Offset(160, 400),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const _Capa('naranja_cuerpo'),
                _Giro(
                  grados: 7 + 1 + _oscila(t, 6),
                  pivote: const Offset(173, 158),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const _Capa('naranja_cabeza'),
                      _Ojos(
                        forma: _ojosNaranja,
                        apertura: _apertura(t, 5, 0),
                        desvio: 2.6 * _oscila(t, 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _Giro(
            grados: -6 - 0.85 - 0.85 * _oscila(t, 6),
            pivote: const Offset(358, 400),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const _Capa('negro_cuerpo'),
                _Giro(
                  grados: -8 - 1.1 - 1.1 * _oscila(t, 4),
                  pivote: const Offset(354, 252),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const _Capa('negro_cabeza'),
                      _Ojos(
                        forma: _ojosNegro,
                        apertura: _apertura(t, 6, 2.4),
                        desvio: -2.8 * _oscila(t, 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _Giro(
            grados: 10 + 0.8 + 0.8 * _oscila(t, 5),
            pivote: const Offset(310, 350),
            child: const _Capa('pata'),
          ),
        ],
      ),
    );
  }
}

const _ojosNaranja = FormaOjos(
  centros: [Offset(146, 158), Offset(202, 156)],
  iris: Size(17, 16),
  pupila: Size(4.5, 13),
  colorIris: Color(0xFFC9D46E),
  colorPupila: Color(0xFF1A1E1C),
  brillo: Offset(-5, -6),
  radioBrillo: 3.4,
);

const _ojosNegro = FormaOjos(
  centros: [Offset(326, 252), Offset(384, 256)],
  iris: Size(18, 17),
  pupila: Size(5, 14),
  colorIris: Color(0xFFE8B923),
  colorPupila: Color(0xFF12140F),
  brillo: Offset(-5, -7),
  radioBrillo: 3.6,
);

/// Una capa del dibujo, a tamaño del lienzo. Superpuestas todas en el mismo
/// sistema de coordenadas, encajan como en el SVG de una pieza.
class _Capa extends StatelessWidget {
  const _Capa(this.nombre);

  final String nombre;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/gatos/$nombre.svg',
      width: _Escena.ancho,
      height: _Escena.alto,
    );
  }
}

/// Gira un subárbol alrededor de un punto del lienzo, no de su centro.
class _Giro extends StatelessWidget {
  const _Giro({
    required this.grados,
    required this.pivote,
    required this.child,
  });

  final double grados;
  final Offset pivote;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: grados * math.pi / 180,
      origin: pivote,
      alignment: Alignment.topLeft,
      child: child,
    );
  }
}

class _Ojos extends StatelessWidget {
  const _Ojos({
    required this.forma,
    required this.apertura,
    required this.desvio,
  });

  final FormaOjos forma;
  final double apertura;
  final double desvio;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(_Escena.ancho, _Escena.alto),
      painter: PintorOjos(
        forma: forma,
        apertura: apertura,
        desvioPupila: desvio,
      ),
    );
  }
}

/// Las tres burbujas verdes del fondo. Son círculos: no hacen falta assets.
class _Burbujas extends StatelessWidget {
  const _Burbujas({required this.t});

  static const List<(Offset, double, double, double)> _burbujas = [
    (Offset(60, 96), 6, 3, -8),
    (Offset(424, 76), 7.5, 4, 9),
    (Offset(452, 140), 4.5, 2.5, -6),
  ];

  final double t;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final (centro, radio, periodo, recorrido) in _burbujas)
          Positioned(
            left: centro.dx - radio,
            top: centro.dy -
                radio +
                recorrido * 0.5 * (1 - _Escena._oscila(t, periodo)),
            child: Container(
              width: radio * 2,
              height: radio * 2,
              decoration: const BoxDecoration(
                color: Color(0xFF01B763),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
