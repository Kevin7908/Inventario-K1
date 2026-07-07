import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Título y subtítulo de una pantalla, con acciones opcionales a la derecha.
///
/// Parámetros:
/// - [titulo]: título principal de la pantalla.
/// - [subtitulo]: descripción debajo del título. Si es `null`, no se muestra.
/// - [acciones]: widget alineado a la derecha, en la misma fila que el título
///   (ej. notificaciones y cuenta del usuario logueado).
///
/// Ejemplo:
/// ```dart
/// EncabezadoPagina(
///   titulo: 'Configuración',
///   subtitulo: 'Ajustes generales del negocio y catálogos base',
///   acciones: CuentaUsuarioWidget(
///     nombre: 'Zaim Maulana',
///     rol: 'Administrador',
///     iniciales: 'ZM',
///   ),
/// )
/// ```
class EncabezadoPagina extends StatelessWidget {
  const EncabezadoPagina({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.acciones,
  });

  final String titulo;
  final String? subtitulo;
  final Widget? acciones;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: TipografiaApp.heading1),
              if (subtitulo != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitulo!,
                  style: TipografiaApp.cuerpo.copyWith(
                    color: ColoresApp.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?acciones,
      ],
    );
  }
}
