import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// El aviso breve de la aplicación: la barra que aparece abajo tras guardar,
/// cobrar o fallar.
///
/// No es un widget sino dos funciones, como `colorDeHex`: lo que se comparte
/// aquí es *cómo se ve* un aviso —color, tipografía y duración—, y el widget
/// que lo pinta es el `SnackBar` de Flutter.
///
/// **Por qué existe.** Cada pantalla tenía su propio `_avisar` con el mismo
/// `ScaffoldMessenger.of(context).showSnackBar(...)` copiado dentro: el mismo
/// trabajo con distinto nombre en cada módulo. Con una sola versión, cambiar
/// el color de un error se hace en un sitio.
///
/// El [BuildContext] tiene que estar debajo de un `Scaffold`. Después de un
/// `await`, comprobar `mounted` antes de llamar —lo exige el lint
/// `use_build_context_synchronously` del §9—.
///
/// Ejemplo:
/// ```dart
/// switch (resultado) {
///   case Exito():          MensajeApp.exito(context, 'Orden guardada');
///   case Fallo(:final mensaje): MensajeApp.error(context, mensaje);
/// }
/// ```
abstract final class MensajeApp {
  /// Algo salió bien. Verde.
  static void exito(BuildContext context, String texto) =>
      _mostrar(context, texto, ColoresApp.statusSuccess);

  /// Algo falló. Rojo, y un poco más de tiempo en pantalla: un error hay que
  /// alcanzar a leerlo.
  static void error(BuildContext context, String texto) => _mostrar(
        context,
        texto,
        ColoresApp.statusDanger,
        duracion: const Duration(seconds: 5),
      );

  static void _mostrar(
    BuildContext context,
    String texto,
    Color fondo, {
    Duration duracion = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          texto,
          style: TipografiaApp.sobrePrimario(TipografiaApp.cuerpo),
        ),
        backgroundColor: fondo,
        duration: duracion,
      ),
    );
  }
}
