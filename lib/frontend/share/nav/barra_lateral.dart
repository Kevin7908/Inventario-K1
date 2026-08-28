import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import 'item_nav.dart';
import 'item_nav_dato.dart';
import 'logo_sidebar.dart';
import 'seccion_nav.dart';
import 'seccion_nav_dato.dart';
import 'separador_nav.dart';

/// Sidebar de navegación principal de la aplicación.
///
/// Ensambla [LogoSidebar], [SeccionNav], [ItemNav] y [SeparadorNav] en una
/// columna fija de ancho 240. El ítem cuya [ItemNavDato.ruta] coincida con
/// [rutaActiva] se muestra como activo.
///
/// Parámetros:
/// - [secciones]: grupos de navegación con título e ítems.
/// - [itemsInferiores]: ítems fijos en el pie (Configuración, Salir, etc.).
/// - [rutaActiva]: ruta actualmente seleccionada para marcar el ítem activo.
/// - [nombreEmpresa]: nombre que muestra [LogoSidebar].
/// - [subtituloEmpresa]: subtítulo que muestra [LogoSidebar].
///
/// Ejemplo:
/// ```dart
/// BarraLateral(
///   rutaActiva: '/dashboard',
///   secciones: [
///     SeccionNavDato(
///       titulo: 'Principal',
///       items: [
///         ItemNavDato(
///           icono: Icons.dashboard_outlined,
///           etiqueta: 'Dashboard',
///           ruta: '/dashboard',
///           alPresionar: () => Get.toNamed('/dashboard'),
///         ),
///       ],
///     ),
///   ],
///   itemsInferiores: [
///     ItemNavDato(
///       icono: Icons.settings_outlined,
///       etiqueta: 'Configuración',
///       ruta: '/configuracion',
///       alPresionar: () => Get.toNamed('/configuracion'),
///     ),
///   ],
/// )
/// ```
class BarraLateral extends StatelessWidget {
  const BarraLateral({
    super.key,
    required this.secciones,
    required this.itemsInferiores,
    required this.rutaActiva,
    this.nombreEmpresa = 'InventarioK1',
    this.subtituloEmpresa = 'Taller de motos',
  });

  final List<SeccionNavDato> secciones;
  final List<ItemNavDato> itemsInferiores;
  final String rutaActiva;
  final String nombreEmpresa;
  final String subtituloEmpresa;

  @override
  Widget build(BuildContext context) {
    // `RepaintBoundary` obligatorio: el resaltado de hover de cada `ItemNav`
    // se anima, y sin capa propia ese repintado ensucia la capa que comparte
    // con todo el contenido de la app. En Linux, donde la barra de título es
    // client-side y vive en la misma superficie, eso se ve como un parpadeo
    // de los botones de minimizar/maximizar/cerrar al pasar el mouse.
    return RepaintBoundary(
      child: Container(
        width: 240,
        color: ColoresApp.bgSidebar,
        child: Column(
          children: [
            LogoSidebar(
              nombreEmpresa: nombreEmpresa,
              subtitulo: subtituloEmpresa,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final seccion in secciones) ...[
                    SeccionNav(titulo: seccion.titulo),
                    for (final item in seccion.items)
                      ItemNav(
                        icono: item.icono,
                        etiqueta: item.etiqueta,
                        activo: rutaActiva == item.ruta,
                        contadorBadge: item.contadorBadge,
                        alPresionar: item.alPresionar,
                      ),
                  ],
                ],
              ),
            ),
            const SeparadorNav(),
            for (final item in itemsInferiores)
              ItemNav(
                icono: item.icono,
                etiqueta: item.etiqueta,
                activo: rutaActiva == item.ruta,
                contadorBadge: item.contadorBadge,
                alPresionar: item.alPresionar,
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
