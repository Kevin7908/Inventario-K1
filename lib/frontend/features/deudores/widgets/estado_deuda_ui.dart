import 'package:flutter/material.dart';

import '../../../../backend/features/deudores/enum/enum_deudor.dart';
import '../../../../backend/features/deudores/modelo/deudor_resumen.dart';
import '../../../share2/share2.dart';

/// Cómo se lee el estado de una deuda, en un solo sitio.
///
/// **`EstadoDeudor` no es lo que hay que mostrar.** La columna guarda `ACTIVA`
/// aunque el plazo se haya cumplido hace un mes, así que pintar el enum tal
/// cual diría «Activa» de la deuda que hay que ir a cobrar hoy.
/// [SituacionDeuda] es la lectura completa —la marca guardada más el
/// calendario—, y es la misma que aplica el repositorio en SQL para contar las
/// vencidas: si las dos se separan, la cabecera dice una cosa y la fila otra.
enum SituacionDeuda { alDia, vencida, pagada, incobrable }

SituacionDeuda situacionDe(DeudorResumen deuda) => switch (deuda.estado) {
      EstadoDeudor.pagada => SituacionDeuda.pagada,
      EstadoDeudor.incobrable => SituacionDeuda.incobrable,
      _ => deuda.estaVencida ? SituacionDeuda.vencida : SituacionDeuda.alDia,
    };

/// El mismo reparto que usan las reservas y las órdenes, para que un documento
/// cerrado se lea igual en las tres pantallas: gris el que sigue en curso,
/// verde el que terminó bien, rojo el que se torció.
///
/// «Incobrable» va en gris y no en rojo: darla por perdida es una decisión ya
/// tomada, no una alarma pendiente. Lo urgente es lo vencido.
({String etiqueta, Color color, Color fondo}) estiloDeSituacion(
  SituacionDeuda situacion,
) =>
    switch (situacion) {
      SituacionDeuda.alDia => (
          etiqueta: 'Al día',
          color: ColoresApp.statusNeutral,
          fondo: ColoresApp.statusNeutralBg,
        ),
      SituacionDeuda.vencida => (
          etiqueta: 'Vencida',
          color: ColoresApp.statusDanger,
          fondo: ColoresApp.statusDangerBg,
        ),
      SituacionDeuda.pagada => (
          etiqueta: 'Pagada',
          color: ColoresApp.statusSuccess,
          fondo: ColoresApp.statusSuccessBg,
        ),
      SituacionDeuda.incobrable => (
          etiqueta: 'Incobrable',
          color: ColoresApp.textMuted,
          fondo: ColoresApp.statusNeutralBg,
        ),
    };

/// El color con que se pinta el avance de una deuda.
///
/// **No es el de una reserva**, y por eso no se comparte: en una reserva ir a
/// medio pagar es lo normal y va en verde; en una deuda vencida es justo lo
/// que hay que ir a cobrar y va en rojo.
Color colorDeAvance(SituacionDeuda situacion) => switch (situacion) {
      SituacionDeuda.pagada => ColoresApp.statusSuccess,
      SituacionDeuda.vencida => ColoresApp.statusDanger,
      SituacionDeuda.incobrable => ColoresApp.textDisabled,
      SituacionDeuda.alDia => ColoresApp.goGreen,
    };

/// El badge de estado de una deuda, tal como lo dibuja el diseño.
///
/// Parámetros:
/// - [deuda]: de ella salen la marca y la fecha de vencimiento.
///
/// Ejemplo:
/// ```dart
/// BadgeSituacionDeuda(deuda: deuda)
/// ```
class BadgeSituacionDeuda extends StatelessWidget {
  const BadgeSituacionDeuda({super.key, required this.deuda});

  final DeudorResumen deuda;

  @override
  Widget build(BuildContext context) {
    final estilo = estiloDeSituacion(situacionDe(deuda));

    return IndicadorEstado(
      etiqueta: estilo.etiqueta,
      color: estilo.color,
      colorFondo: estilo.fondo,
    );
  }
}
