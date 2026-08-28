import 'package:flutter/material.dart';

import '../temas/colores_app.dart';

/// El aside derecho de las pantallas de dos paneles: el documento que se está
/// armando, sea un carrito, una cotización o una orden.
///
/// Es solo el marco —ancho fijo, borde a la izquierda, y el reparto en tres
/// franjas— porque es lo único que las tres comparten de verdad. La cabecera
/// dice a quién se le vende y el pie ofrece cobrar, reservar o imprimir: eso
/// cambia en cada módulo y llega ya construido.
///
/// El [ancho] es una constante del diseño y por eso vive aquí: con una copia
/// por pantalla, cambiarlo obligaba a acordarse de las tres.
///
/// Parámetros:
/// - [cabecera]: la franja de arriba, de alto natural.
/// - [contenido]: el medio, que se estira y hace scroll por su cuenta.
/// - [pie]: la franja de abajo, de alto natural.
///
/// Ejemplo:
/// ```dart
/// PanelDocumento(
///   cabecera: _Cabecera(),
///   contenido: _Lineas(),
///   pie: _Pie(alCobrar: cobrar),
/// )
/// ```
class PanelDocumento extends StatelessWidget {
  const PanelDocumento({
    super.key,
    required this.cabecera,
    required this.contenido,
    required this.pie,
  });

  /// El del diseño. Se expone para que la pantalla pueda reservarle el sitio
  /// al calcular cuánto le queda al panel de la izquierda.
  static const double ancho = 360;

  final Widget cabecera;
  final Widget contenido;
  final Widget pie;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ancho,
      decoration: const BoxDecoration(
        color: ColoresApp.bgCard,
        border: Border(left: BorderSide(color: ColoresApp.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cabecera,
          Expanded(child: contenido),
          pie,
        ],
      ),
    );
  }
}
