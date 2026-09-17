import 'package:flutter/material.dart';

import '../../../../backend/features/compras/enum/enum_compras.dart';
import '../../../share/share.dart';

/// Cómo se ve cada estado de una compra: color de texto y de fondo de la
/// pastilla.
///
/// Vive en el módulo y no en `share` porque traduce un enum del backend, y
/// `share` no importa nada de `backend/` (§1). Es la misma pieza que
/// `estado_orden_ui.dart` y `estado_deuda_ui.dart`, con el enum de aquí.
///
/// Ámbar para el borrador —está a medio hacer, aunque su mercancía ya entró—,
/// verde para la terminada y rojo para la anulada.
({Color color, Color fondo}) coloresDeEstadoCompra(EstadoCompra estado) =>
    switch (estado) {
      EstadoCompra.borrador => (
          color: ColoresApp.statusWarning,
          fondo: ColoresApp.statusWarningBg,
        ),
      EstadoCompra.registrada => (
          color: ColoresApp.statusSuccess,
          fondo: ColoresApp.statusSuccessBg,
        ),
      EstadoCompra.anulada => (
          color: ColoresApp.statusDanger,
          fondo: ColoresApp.statusDangerBg,
        ),
    };

/// La pastilla de estado, con los colores que le tocan.
///
/// La comparten la tabla del listado, la cabecera de la ficha y el vistazo
/// desde la ficha del producto: son tres sitios que decían lo mismo con tres
/// `IndicadorEstado` armados a mano.
///
/// Ejemplo:
/// ```dart
/// BadgeEstadoCompra(estado: compra.estado)
/// ```
class BadgeEstadoCompra extends StatelessWidget {
  const BadgeEstadoCompra({super.key, required this.estado});

  final EstadoCompra estado;

  @override
  Widget build(BuildContext context) {
    final colores = coloresDeEstadoCompra(estado);
    return IndicadorEstado(
      etiqueta: estado.etiqueta,
      color: colores.color,
      colorFondo: colores.fondo,
    );
  }
}
