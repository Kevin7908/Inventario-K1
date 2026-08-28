import 'package:flutter/material.dart';

/// Convierte `#RRGGBB` en [Color]. Devuelve `null` si el texto no es un hex
/// válido, y quien lo use cae a su color por defecto.
///
/// Varias entidades guardan su color como texto en la base (`Categoria`,
/// `Proveedor`). Este es el único parser: antes vivía en la vista de
/// Categorías, y cada módulo nuevo tendía a escribir el suyo.
///
/// Ejemplo:
/// ```dart
/// MarcadorIdentidad(
///   inicial: inicialDe(categoria.nombre),
///   color: colorDeHex(categoria.colorHex),
/// )
/// ```
Color? colorDeHex(String hex) {
  final limpio = hex.replaceAll('#', '').trim();
  if (limpio.length != 6) return null;
  final valor = int.tryParse(limpio, radix: 16);
  return valor == null ? null : Color(0xFF000000 | valor);
}

/// Inicial en mayúscula de un nombre. Cadena vacía si el nombre lo está.
String inicialDe(String nombre) =>
    nombre.trim().isEmpty ? '' : nombre.trim()[0].toUpperCase();
