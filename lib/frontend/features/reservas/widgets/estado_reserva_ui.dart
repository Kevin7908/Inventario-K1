import 'package:flutter/material.dart';

import '../../../../backend/features/reservas/enum/enum_reserva.dart';
import '../../../../backend/features/reservas/modelo/reserva_resumen.dart';
import '../../../share2/share2.dart';

/// Cómo se ven los dos estados de una reserva, que son dos y no uno.
///
/// Vive en el módulo y no en `share2` porque traduce enums del backend, y
/// `share2` no importa nada de `backend/` (§1).
///
/// - **El del dinero** ([BadgeSaldoReserva]): `Pagada` o `Abonando`. Es el que
///   lleva la tarjeta del diseño, y es derivado —no hay columna que lo guarde—.
/// - **El del ciclo de vida** ([BadgeEstadoReserva]): dónde está la mercancía.
///   Solo se muestra cuando dice algo que el otro no: una reserva `ACTIVA` ya
///   se entiende por su saldo, pero una cancelada hay que decirla.

({Color color, Color fondo}) coloresDeEstadoReserva(EstadoReserva estado) =>
    switch (estado) {
      EstadoReserva.activa => (
          color: ColoresApp.statusNeutral,
          fondo: ColoresApp.statusNeutralBg,
        ),
      EstadoReserva.completada => (
          color: ColoresApp.statusInfo,
          fondo: ColoresApp.statusInfoBg,
        ),
      EstadoReserva.cancelada => (
          color: ColoresApp.statusDanger,
          fondo: ColoresApp.statusDangerBg,
        ),
    };

/// Verde si no queda saldo, ámbar si todavía se está abonando. Son los mismos
/// colores del mockup.
({Color color, Color fondo}) coloresDeSaldo({required bool pagada}) => pagada
    ? (color: ColoresApp.statusSuccess, fondo: ColoresApp.statusSuccessBg)
    : (color: ColoresApp.statusWarning, fondo: ColoresApp.statusWarningBg);

/// La pastilla del dinero: `Pagada` o `Abonando`.
class BadgeSaldoReserva extends StatelessWidget {
  const BadgeSaldoReserva({super.key, required this.reserva});

  final ReservaResumen reserva;

  @override
  Widget build(BuildContext context) {
    final colores = coloresDeSaldo(pagada: reserva.pagada);
    return IndicadorEstado(
      etiqueta: reserva.pagada ? 'Pagada' : 'Abonando',
      color: colores.color,
      colorFondo: colores.fondo,
    );
  }
}

/// La pastilla del ciclo de vida: dónde está la mercancía.
class BadgeEstadoReserva extends StatelessWidget {
  const BadgeEstadoReserva({super.key, required this.estado});

  final EstadoReserva estado;

  @override
  Widget build(BuildContext context) {
    final colores = coloresDeEstadoReserva(estado);
    return IndicadorEstado(
      etiqueta: estado.etiqueta,
      color: colores.color,
      colorFondo: colores.fondo,
    );
  }
}
