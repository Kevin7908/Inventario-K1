import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// El hueco de una lista que todavía no tiene nada, con su explicación.
///
/// Es el bloque centrado del diseño: ícono grande y tenue, una línea que dice
/// qué está vacío y otra que dice cómo llenarlo. La segunda no es adorno —un
/// «Sin resultados» a secas deja al usuario sin saber si falló él o la app—.
///
/// Parámetros:
/// - [icono]: el del contenido que falta (un carrito, una orden, una factura).
/// - [titulo]: qué está vacío, en una línea.
/// - [pista]: qué hacer para llenarlo. Opcional: en una búsqueda sin
///   resultados a veces no hay nada que sugerir.
///
/// Ejemplo:
/// ```dart
/// EstadoVacio(
///   icono: Icons.shopping_cart_outlined,
///   titulo: 'El carrito está vacío',
///   pista: 'Toca un producto de la izquierda para agregarlo.',
/// )
/// ```
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    this.pista,
  });

  final IconData icono;
  final String titulo;
  final String? pista;

  @override
  Widget build(BuildContext context) {
    final pista = this.pista;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 40, color: ColoresApp.textDisabled),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: TipografiaApp.cuerpo,
            ),
            if (pista != null) ...[
              const SizedBox(height: 4),
              Text(
                pista,
                textAlign: TextAlign.center,
                style: TipografiaApp.caption,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
