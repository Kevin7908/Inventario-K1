import 'package:flutter/material.dart';

import '../../../../backend/features/bitacora/modelo/entrada_bitacora.dart';
import '../../../share/share.dart';

/// Cómo se ve cada acción de la bitácora: color, fondo e ícono.
///
/// Vive aquí y no en `share` porque conoce `AccionAuditada`, que es dominio.
/// Y vive en **un solo sitio** porque la tabla, los chips del filtro y
/// cualquier resumen futuro tienen que pintar «Eliminó» del mismo rojo: con
/// una copia por pantalla, el día que se agregue una acción quedaría gris en
/// la mitad de ellas.
///
/// Los colores son los semánticos de [ColoresApp] —éxito, info, alerta,
/// error—, no los decorativos de marca: aquí el color dice qué pasó.
///
/// Ejemplo:
/// ```dart
/// final estilo = EstiloAccion.de(entrada.accion);
/// IndicadorEstado(
///   etiqueta: entrada.accion.etiqueta,
///   color: estilo.color,
///   colorFondo: estilo.fondo,
/// )
/// ```
final class EstiloAccion {
  const EstiloAccion._({
    required this.color,
    required this.fondo,
    required this.icono,
  });

  final Color color;
  final Color fondo;
  final IconData icono;

  static const _creo = EstiloAccion._(
    color: ColoresApp.statusSuccess,
    fondo: ColoresApp.statusSuccessBg,
    icono: Icons.add_rounded,
  );

  static const _modifico = EstiloAccion._(
    color: ColoresApp.statusInfo,
    fondo: ColoresApp.statusInfoBg,
    icono: Icons.edit_outlined,
  );

  static const _elimino = EstiloAccion._(
    color: ColoresApp.statusDanger,
    fondo: ColoresApp.statusDangerBg,
    icono: Icons.delete_outline_rounded,
  );

  static const _anulo = EstiloAccion._(
    color: ColoresApp.statusWarning,
    fondo: ColoresApp.statusWarningBg,
    icono: Icons.block_outlined,
  );

  /// Ámbar como [_anulo] —las dos deshacen plata— pero con la flecha de
  /// vuelta: devolver le quita una parte a la venta, anular la deshace entera,
  /// y quien revisa la caja tiene que distinguirlas sin leer el renglón.
  static const _devolvio = EstiloAccion._(
    color: ColoresApp.statusWarning,
    fondo: ColoresApp.statusWarningBg,
    icono: Icons.keyboard_return_rounded,
  );

  static EstiloAccion de(AccionAuditada accion) => switch (accion) {
        AccionAuditada.creo => _creo,
        AccionAuditada.modifico => _modifico,
        AccionAuditada.elimino => _elimino,
        AccionAuditada.anulo => _anulo,
        AccionAuditada.devolvio => _devolvio,
      };
}
