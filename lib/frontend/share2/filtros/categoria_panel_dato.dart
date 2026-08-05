import 'package:flutter/material.dart';

/// Datos de una categoría para pintarla en [PanelCategorias].
///
/// Es un DTO de presentación: el módulo traduce su modelo de dominio a esta
/// forma (por ejemplo `Categoria.colorHex` ya convertido a [Color]) para que
/// el panel no sepa nada del backend.
///
/// Parámetros:
/// - [id]: identificador con el que el módulo filtra.
/// - [nombre]: texto visible; su inicial se usa como marcador cuando no hay
///   [icono].
/// - [color]: color de acento de la categoría. Si es `null`, el panel usa su
///   color por defecto.
/// - [icono]: ícono opcional. Sin él, el panel dibuja la inicial del [nombre]
///   sobre un círculo con [color], que es lo único que distingue una categoría
///   de otra cuando el panel está contraído.
/// - [subcategorias]: nombres del segundo nivel. Si está vacía, el ítem no
///   muestra el control de despliegue.
///
/// Ejemplo:
/// ```dart
/// CategoriaPanelDato(
///   id: categoria.id!,
///   nombre: categoria.nombre,
///   color: const Color(0xFF01B763),
/// )
/// ```
class CategoriaPanelDato {
  const CategoriaPanelDato({
    required this.id,
    required this.nombre,
    this.color,
    this.icono,
    this.subcategorias = const [],
  });

  final int id;
  final String nombre;
  final Color? color;
  final IconData? icono;
  final List<String> subcategorias;

  /// Inicial en mayúscula para el marcador. Cadena vacía si el nombre lo está.
  String get inicial =>
      nombre.trim().isEmpty ? '' : nombre.trim()[0].toUpperCase();
}
