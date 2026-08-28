import 'package:flutter/services.dart';

import '../../../core/formato.dart';

/// Agrupa los miles mientras se escribe: al teclear `45000` se ve `45.000`.
///
/// Lo usa `CampoTexto` con `comoPrecio: true`. Es un formateador y no un
/// `NumberFormat` aplicado al guardar porque el usuario tiene que **ver** la
/// cifra agrupada mientras la escribe: en un precio de seis dígitos, un cero
/// de más no se detecta a simple vista sin los puntos.
///
/// El separador sale de `core/formato.dart`, que es el único sitio del
/// proyecto donde se decide cómo se ve un número (`CLAUDE.md` §6).
///
/// **El texto resultante lleva puntos**, así que quien guarda pasa el valor
/// por `normalizarDigitos` antes de convertirlo a entero.
///
/// Ejemplo:
/// ```dart
/// CampoTexto(
///   etiqueta: 'Precio de venta *',
///   controlador: _precioCtrl,
///   comoPrecio: true,
/// )
/// ```
class FormateadorMiles extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue nuevo,
  ) {
    final digitos = nuevo.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.isEmpty) return nuevo.copyWith(text: '');

    // Un número más largo que esto no es un precio, es un error de tecleo, y
    // `int.parse` reventaría con dieciocho dígitos.
    if (digitos.length > 15) return anterior;

    final texto = agruparMiles(int.parse(digitos));

    // El cursor se queda al final: es donde lo espera quien está tecleando, y
    // recolocarlo en medio de un número que acaba de cambiar de largo hace que
    // salte solo.
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
