import 'package:flutter/material.dart';

/// La forma de los ojos de un gato de la ilustración.
///
/// Los ojos no están en el SVG: se pintan aquí porque son lo único que
/// parpadea, y un párpado que sigue a una cabeza que gira sale más barato
/// dibujándolo dentro de la misma transformación que recortando otro asset.
///
/// Los colores son los del dibujo —pelaje, iris, pupila—, no tokens del tema:
/// `ColoresApp` describe la marca, no el color del ojo de un gato.
class FormaOjos {
  const FormaOjos({
    required this.centros,
    required this.iris,
    required this.pupila,
    required this.colorIris,
    required this.colorPupila,
    required this.brillo,
    required this.radioBrillo,
  });

  /// Los dos ojos, en coordenadas del lienzo de 480×408.
  final List<Offset> centros;

  /// Radios del iris y de la pupila.
  final Size iris;
  final Size pupila;

  final Color colorIris;
  final Color colorPupila;

  /// Punto de luz, relativo al centro del ojo.
  final Offset brillo;
  final double radioBrillo;
}

/// Pinta los dos ojos de un gato con su parpadeo y su pupila movida.
///
/// Parámetros:
/// - [forma]: dónde van y de qué color.
/// - [apertura]: 1 = abierto, 0 = cerrado. El parpadeo aplasta el ojo en
///   vertical, que es lo que hacía el `scale` del SVG original.
/// - [desvioPupila]: cuánto se corre la pupila a los lados, en píxeles del
///   lienzo.
class PintorOjos extends CustomPainter {
  const PintorOjos({
    required this.forma,
    required this.apertura,
    required this.desvioPupila,
  });

  final FormaOjos forma;
  final double apertura;
  final double desvioPupila;

  static final Paint _blanco = Paint()..color = const Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final iris = Paint()..color = forma.colorIris;
    final pupila = Paint()..color = forma.colorPupila;

    for (final centro in forma.centros) {
      canvas.save();
      canvas.translate(centro.dx, centro.dy);
      canvas.scale(1, apertura);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: forma.iris.width * 2,
          height: forma.iris.height * 2,
        ),
        iris,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(desvioPupila, 0),
          width: forma.pupila.width * 2,
          height: forma.pupila.height * 2,
        ),
        pupila,
      );
      canvas.drawCircle(forma.brillo, forma.radioBrillo, _blanco);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(PintorOjos anterior) =>
      anterior.apertura != apertura ||
      anterior.desvioPupila != desvioPupila ||
      anterior.forma != forma;
}
