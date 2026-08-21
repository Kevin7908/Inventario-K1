import 'package:flutter/material.dart';

import '../../../core/formato.dart';
import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Separador de un bloque de líneas dentro de un documento, con su subtotal.
///
/// Los documentos del taller reparten sus líneas por tipo —mano de obra,
/// repuestos, cargos sueltos— y cada bloque muestra cuánto suma. Mezclados no
/// hay forma de ver de un vistazo cuánto es trabajo y cuánto son piezas, que
/// es justo lo que se discute con el cliente al entregar.
///
/// Parámetros:
/// - [icono]: el del tipo de línea del bloque. Lo elige el módulo: el mismo
///   ícono significa «producto» en una cotización y «repuesto» en una orden.
/// - [titulo]: el nombre del bloque, en plural («Repuestos»).
/// - [subtotal]: la suma del bloque, en pesos enteros. Se formatea aquí.
///
/// Ejemplo:
/// ```dart
/// EncabezadoGrupoLineas(
///   icono: Icons.build_outlined,
///   titulo: 'Servicios',
///   subtotal: grupo.subtotal,
/// )
/// ```
class EncabezadoGrupoLineas extends StatelessWidget {
  const EncabezadoGrupoLineas({
    super.key,
    required this.icono,
    required this.titulo,
    required this.subtotal,
  });

  final IconData icono;
  final String titulo;
  final int subtotal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Row(
        children: [
          Icon(icono, size: 14, color: ColoresApp.textMuted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              titulo,
              style: TipografiaApp.overline.copyWith(
                color: ColoresApp.textMuted,
              ),
            ),
          ),
          Text(
            formatearPrecio(subtotal),
            style: TipografiaApp.overline.copyWith(
              color: ColoresApp.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
