import 'package:flutter/material.dart';

import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../share2/share2.dart';

/// Chip con el estado de stock de un producto.
///
/// Traduce [EstadoStock] a la pareja de colores del semáforo de `ColoresApp` y
/// delega el dibujo en [IndicadorEstado] de share2, para que se vea igual que
/// cualquier otro estado de la aplicación.
class BadgeEstadoStock extends StatelessWidget {
  const BadgeEstadoStock({
    super.key,
    required this.estado,
    this.conPunto = true,
  });

  final EstadoStock estado;
  final bool conPunto;

  @override
  Widget build(BuildContext context) {
    final (etiqueta, color, fondo) = switch (estado) {
      EstadoStock.enStock => (
          'En stock',
          ColoresApp.stockOk,
          ColoresApp.statusSuccessBg,
        ),
      EstadoStock.stockBajo => (
          'Stock bajo',
          ColoresApp.stockLow,
          ColoresApp.statusWarningBg,
        ),
      EstadoStock.sinStock => (
          'Agotado',
          ColoresApp.stockOut,
          ColoresApp.statusDangerBg,
        ),
    };

    return IndicadorEstado(
      etiqueta: etiqueta,
      color: color,
      colorFondo: fondo,
      conPunto: conPunto,
    );
  }
}
