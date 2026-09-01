import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formato.dart';
import '../../../share/share.dart';
import '../provider/compras_providers.dart';

/// «$1.240.000 este mes · última hace 12 días», en la tarjeta del proveedor.
///
/// Responde la pregunta que el taller hace todos los meses y que la app no
/// podía contestar mientras dar entrada fuera producto + cantidad. Vive en
/// `compras/` —el módulo dueño del dato— y la importa Proveedores, como manda
/// el README del frontend.
///
/// Es un `ConsumerWidget` propio para que la grilla de proveedores no se
/// repinte entera cuando entra una compra: cada tarjeta observa la suya.
///
/// Parámetros:
/// - [proveedorId]: de quién se está mirando la tarjeta.
///
/// Ejemplo:
/// ```dart
/// LineaComprasProveedor(proveedorId: proveedor.id!)
/// ```
class LineaComprasProveedor extends ConsumerWidget {
  const LineaComprasProveedor({super.key, required this.proveedorId});

  final int proveedorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(resumenProveedorComprasProvider(proveedorId));
    final datos = resumen.value;

    // Mientras carga no se pinta nada: un «$0 este mes» que después cambia se
    // lee como un dato, no como un cargando.
    if (datos == null) return const SizedBox.shrink();

    if (datos.invertidoTotal == 0) {
      return const FilaDato(
        icono: Icons.receipt_outlined,
        texto: 'Sin compras registradas',
        color: ColoresApp.textDisabled,
      );
    }

    return FilaDato(
      icono: Icons.receipt_outlined,
      texto: '${formatearPrecio(datos.invertidoMes)} este mes'
          '${_ultima(datos.ultimaCompra)}',
    );
  }

  /// Cuánto hace de la última, en palabras. El número solo —«hace 0 días»— se
  /// lee mal.
  String _ultima(DateTime? fecha) {
    if (fecha == null) return '';
    final dias = DateTime.now().difference(fecha).inDays;
    return switch (dias) {
      0 => ' · la última, hoy',
      1 => ' · la última, ayer',
      final d when d < 31 => ' · la última hace $d días',
      _ => ' · la última el ${formatearFecha(fecha)}',
    };
  }
}
