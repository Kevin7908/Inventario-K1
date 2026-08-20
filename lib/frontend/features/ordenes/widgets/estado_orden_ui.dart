import 'package:flutter/material.dart';

import '../../../../backend/features/ventas/ordenes/enum/enum_ordenes.dart';
import '../../../share2/share2.dart';

/// Cómo se ve cada estado de orden: color de texto y de fondo de la pastilla.
///
/// Vive en el módulo y no en `share2` porque traduce un enum del backend, y
/// `share2` no importa nada de `backend/` (§1).
///
/// Los colores salen del diseño: naranja para lo que está en curso, gris para
/// lo que espera al cliente, verde para lo entregado y rojo para lo anulado.
({Color color, Color fondo}) coloresDeEstadoOrden(EstadoOrden estado) =>
    switch (estado) {
      EstadoOrden.abierta => (
          color: ColoresApp.statusWarning,
          fondo: ColoresApp.statusWarningBg,
        ),
      EstadoOrden.lista => (
          color: ColoresApp.statusNeutral,
          fondo: ColoresApp.statusNeutralBg,
        ),
      EstadoOrden.entregada => (
          color: ColoresApp.statusSuccess,
          fondo: ColoresApp.statusSuccessBg,
        ),
      EstadoOrden.anulada => (
          color: ColoresApp.statusDanger,
          fondo: ColoresApp.statusDangerBg,
        ),
    };

/// La pastilla de estado de la tabla, con los colores que le tocan.
class BadgeEstadoOrden extends StatelessWidget {
  const BadgeEstadoOrden({super.key, required this.estado});

  final EstadoOrden estado;

  @override
  Widget build(BuildContext context) {
    final colores = coloresDeEstadoOrden(estado);
    return IndicadorEstado(
      etiqueta: estado.etiqueta,
      color: colores.color,
      colorFondo: colores.fondo,
    );
  }
}
