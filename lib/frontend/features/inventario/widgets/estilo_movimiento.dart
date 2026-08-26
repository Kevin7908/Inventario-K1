import 'package:flutter/material.dart';

import '../../../../backend/features/inventario/modelo/movimiento_inventario.dart';
import '../../../share2/share2.dart';

/// Cómo se ve un movimiento de inventario: color, fondo e ícono.
///
/// Vive aquí y no en `share2` porque conoce `TipoMovimiento`, que es dominio.
/// Y vive en **un solo sitio** porque lo pintan tres pantallas —el kardex, la
/// ficha del producto y los chips del filtro—: con una copia por pantalla, el
/// día que se agregue un tipo quedaría gris en dos de ellas.
///
/// **El color lo decide el signo, no el tipo.** Lo que entra es verde y lo que
/// sale es rojo, siempre, porque es lo primero que busca quien mira la lista;
/// el ícono es el que dice *por qué*. Es la misma decisión que tomó la tabla al
/// guardar el signo en la cantidad en vez de deducirlo del tipo.
///
/// Ejemplo:
/// ```dart
/// final estilo = EstiloMovimiento.de(movimiento.tipo);
/// Icon(estilo.icono, color: estilo.color)
/// ```
final class EstiloMovimiento {
  const EstiloMovimiento._({
    required this.color,
    required this.fondo,
    required this.icono,
  });

  final Color color;
  final Color fondo;
  final IconData icono;

  /// El ícono de cada tipo. El color sale aparte, del signo.
  static const Map<TipoMovimiento, IconData> _iconos = {
    TipoMovimiento.ajusteInicial: Icons.flag_outlined,
    TipoMovimiento.ajustePositivo: Icons.tune_rounded,
    TipoMovimiento.ajusteNegativo: Icons.tune_rounded,
    TipoMovimiento.entradaCompra: Icons.local_shipping_outlined,
    TipoMovimiento.salidaVenta: Icons.point_of_sale_outlined,
    TipoMovimiento.salidaServicio: Icons.build_outlined,
    TipoMovimiento.salidaReserva: Icons.bookmark_border_rounded,
    TipoMovimiento.salidaFiado: Icons.handshake_outlined,
    TipoMovimiento.devolucionVenta: Icons.keyboard_return_rounded,
    TipoMovimiento.devolucionServicio: Icons.keyboard_return_rounded,
    TipoMovimiento.devolucionReserva: Icons.keyboard_return_rounded,
    TipoMovimiento.devolucionFiado: Icons.keyboard_return_rounded,
  };

  /// [entra] manda sobre [tipo] para el color: un `AJUSTE_POSITIVO` y una
  /// `DEVOLUCION_VENTA` son la misma noticia para quien cuenta la estantería.
  static EstiloMovimiento de(TipoMovimiento tipo, {required bool entra}) =>
      EstiloMovimiento._(
        color: entra ? ColoresApp.statusSuccess : ColoresApp.statusDanger,
        fondo: entra ? ColoresApp.statusSuccessBg : ColoresApp.statusDangerBg,
        icono: _iconos[tipo] ?? Icons.swap_vert_rounded,
      );
}

/// La cantidad con su signo delante, sin decimales cuando no hacen falta.
///
/// «+12», «−3», «+0.5». No va en `lib/core/formato.dart` porque no es un
/// formato de la app sino la convención de esta tabla: en el resto de las
/// pantallas una cantidad no lleva signo.
String formatearCantidadMovimiento(double cantidad) {
  final magnitud = cantidad.abs();
  final texto = magnitud % 1 == 0
      ? magnitud.toInt().toString()
      : magnitud.toStringAsFixed(2);
  return '${cantidad > 0 ? '+' : '−'}$texto';
}
