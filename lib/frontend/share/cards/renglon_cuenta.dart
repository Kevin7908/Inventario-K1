import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Un renglón «etiqueta a la izquierda, importe a la derecha» del bloque de
/// cuentas de un documento.
///
/// Lo comparten el pie de una reserva y el de una deuda, que son el mismo
/// bloque con distintas palabras: total, lo entregado y lo que falta. El
/// **color lo decide quien lo usa**, porque qué es una buena noticia cambia
/// según el documento —un saldo pendiente en una reserva es normal y va en
/// ámbar; en una deuda vencida es lo que hay que ir a cobrar—.
///
/// El importe llega **ya formateado**: share no depende de `intl`, así que
/// quien lo usa le pasa `formatearPrecio`.
///
/// Parámetros:
/// - [etiqueta]: el texto tenue de la izquierda.
/// - [valor]: el importe ya formateado.
/// - [color]: el del importe. Por defecto el texto principal.
///
/// Ejemplo:
/// ```dart
/// RenglonCuenta(
///   etiqueta: 'Saldo pendiente',
///   valor: formatearPrecio(saldo),
///   color: ColoresApp.statusWarning,
/// )
/// ```
class RenglonCuenta extends StatelessWidget {
  const RenglonCuenta({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.color,
  });

  final String etiqueta;
  final String valor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            etiqueta,
            style: TipografiaApp.caption.copyWith(fontSize: 12.5),
          ),
        ),
        Text(
          valor,
          style: TipografiaApp.cuerpoMedium.copyWith(
            fontSize: 13,
            color: color ?? ColoresApp.textPrimary,
          ),
        ),
      ],
    );
  }
}
