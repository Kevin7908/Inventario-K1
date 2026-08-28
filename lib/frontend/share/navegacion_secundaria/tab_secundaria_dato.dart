import 'package:flutter/material.dart';

/// Datos de una pestaña de [BarraTabsSecundaria].
///
/// Ejemplo:
/// ```dart
/// TabSecundariaDato(etiqueta: 'General', alPresionar: () => controlador.cambiarTab(0))
/// ```
class TabSecundariaDato {
  const TabSecundariaDato({
    required this.etiqueta,
    required this.alPresionar,
  });

  final String etiqueta;
  final VoidCallback alPresionar;
}
