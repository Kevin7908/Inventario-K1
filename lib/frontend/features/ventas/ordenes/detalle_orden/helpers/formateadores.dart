export '../../../../../share/formateadores/moneda_formateador.dart'
    show fmtMoneda;

import '../../../../../../core/formato.dart';

/// Fecha corta del detalle de orden. Delega en `core/formato.dart`, que es la
/// fuente única: aquí había un formateador propio de moneda —con separador de
/// miles hecho a mano y dos decimales— que daba un resultado distinto al del
/// resto de la app para el mismo importe.
String fmtFecha(DateTime fecha) => formatearFecha(fecha);
