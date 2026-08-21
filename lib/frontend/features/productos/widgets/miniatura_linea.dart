import 'package:flutter/material.dart';

import '../../../share2/share2.dart';
import '../vista/producto_vista.dart' show MiniaturaProducto;

/// El cuadro de 48 de una línea de documento: la foto del producto, o el ícono
/// de lo que sea esa línea cuando no hay foto que mostrar.
///
/// **No vive en share2** aunque lo usen tres pantallas: por dentro lee la
/// imagen del disco a través de [MiniaturaProducto], y share2 no toca
/// archivos. Vive en el módulo dueño del dato, como `GrillaProductosCatalogo`.
///
/// El ícono alterno no es un adorno: una cotización y una orden mezclan
/// productos con servicios y cargos sueltos, que no tienen foto ni la van a
/// tener. Sin él, esas líneas dejarían un cuadro gris que no dice nada.
///
/// Parámetros:
/// - [rutaImagen]: la foto del producto. `null` o vacía cae en el ícono.
/// - [iconoAlterno]: qué pintar cuando no hay foto.
/// - [lado]: el tamaño del cuadro. 48 por defecto, que es el de las líneas.
///
/// Ejemplo:
/// ```dart
/// MiniaturaLinea(
///   rutaImagen: fotos[linea.productoId],
///   iconoAlterno: Icons.build_outlined,
/// )
/// ```
class MiniaturaLinea extends StatelessWidget {
  const MiniaturaLinea({
    super.key,
    required this.rutaImagen,
    required this.iconoAlterno,
    this.lado = 48,
  });

  final String? rutaImagen;
  final IconData iconoAlterno;
  final double lado;

  @override
  Widget build(BuildContext context) {
    final ruta = rutaImagen;
    if (ruta != null && ruta.isNotEmpty) {
      return MiniaturaProducto(rutaImagen: ruta, lado: lado, radio: 11);
    }

    return Container(
      width: lado,
      height: lado,
      decoration: BoxDecoration(
        color: ColoresApp.bgInput,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        iconoAlterno,
        size: lado * 0.375,
        color: ColoresApp.textDisabled,
      ),
    );
  }
}
