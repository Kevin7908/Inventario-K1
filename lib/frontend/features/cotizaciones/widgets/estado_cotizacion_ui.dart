import 'package:flutter/widgets.dart';

import '../../../../backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import '../../../share2/share2.dart';

/// Cómo se ve cada estado de vigencia en la interfaz.
///
/// Vive en el módulo y no en share2 porque traduce un concepto del negocio —qué
/// tan cerca está de vencer una cotización— a los tokens de color. `share2`
/// aporta el chip ([IndicadorEstado]); aquí solo se decide qué texto y qué
/// pareja de colores le toca a cada estado.
///
/// Ejemplo:
/// ```dart
/// IndicadorEstado(
///   etiqueta: estado.etiqueta,
///   color: estado.color,
///   colorFondo: estado.colorFondo,
/// )
/// ```
extension EstadoCotizacionUi on EstadoCotizacion {
  String get etiqueta => switch (this) {
        EstadoCotizacion.vigente => 'Vigente',
        EstadoCotizacion.porVencer => 'Por vencer',
        EstadoCotizacion.vencida => 'Vencida',
      };

  Color get color => switch (this) {
        EstadoCotizacion.vigente => ColoresApp.statusSuccess,
        EstadoCotizacion.porVencer => ColoresApp.statusWarning,
        EstadoCotizacion.vencida => ColoresApp.statusDanger,
      };

  Color get colorFondo => switch (this) {
        EstadoCotizacion.vigente => ColoresApp.statusSuccessBg,
        EstadoCotizacion.porVencer => ColoresApp.statusWarningBg,
        EstadoCotizacion.vencida => ColoresApp.statusDangerBg,
      };
}
