import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend/share/dominio/permiso.dart';
import '../features/autenticacion/provider/auth_providers.dart';
import '../features/bitacora/vista/bitacora_vista.dart';
import '../features/categorias/vista/categorias_vistas.dart';
import '../features/clientes/vista/cliente_vista.dart';
import '../features/configuracion/vista/configuracion_vista.dart';
import '../features/cotizaciones/vista/cotizaciones_vista.dart';
import '../features/deudores/vista/deudores_vista.dart';
import '../features/inventario/vista/movimientos_vista.dart';
import '../features/pos/vista/punto_venta_vista.dart';
import '../features/ventas/vista/historial_ventas_vista.dart';
import '../features/productos/vista/producto_vista.dart';
import '../features/proveedores/vista/proveedores_vista.dart';
import '../features/reservas/vista/reservas_vista.dart';
import '../features/tecnicos/vista/tecnico_vista.dart';
import '../features/ordenes/vista/ordenes_vista.dart';
import '../share/feedback/dialogo_confirmacion.dart';
import '../share/nav/barra_lateral.dart';
import '../share/nav/item_nav_dato.dart';
import '../share/nav/seccion_nav_dato.dart';
import '../share/temas/colores_app.dart';
import '../share/temas/tipografia_app.dart';

class LayoutPrincipal extends ConsumerStatefulWidget {
  const LayoutPrincipal({super.key});

  @override
  ConsumerState<LayoutPrincipal> createState() => _LayoutPrincipalState();
}

class _LayoutPrincipalState extends ConsumerState<LayoutPrincipal> {
  int _indiceActivo = 0;

  /// Índices ya visitados. El `IndexedStack` mantiene vivas sus hijas, así que
  /// solo se construyen las pantallas por las que se pasó al menos una vez;
  /// las demás quedan como un hueco vacío. Antes se construían las doce al
  /// arrancar, con sus providers y sus consultas a la base de datos.
  final Set<int> _visitadas = {0};

  // Orden paralelo al IndexedStack — si se agrega una vista, va en ambos lugares
  static const List<String> _rutas = [
    '/dashboard',
    '/venta',
    '/historial-ventas',
    '/productos',
    '/movimientos',
    '/categorias',
    '/proveedores',
    '/ordenes',
    '/cotizaciones',
    '/reservas',
    '/tecnicos',
    '/clientes',
    '/deudores',
    '/bitacora',
    '/configuracion',
  ];

  /// Vistas en el mismo orden que [_rutas]. `const`, así que la lista no cuesta
  /// nada: lo que cuesta es construirlas, y eso solo pasa al visitarlas.
  static const List<Widget> _vistas = [
    _PlaceholderVista(etiqueta: 'Dashboard'),
    PuntoVentaVista(),
    HistorialVentasVista(),
    ProductosVista(),
    MovimientosVista(),
    CategoriasVista(),
    ProveedoresVista(),
    OrdenesVista(),
    CotizacionesVista(),
    ReservasVista(),
    TecnicosVista(),
    ClientesVista(),
    DeudoresVista(),
    BitacoraVista(),
    ConfiguracionVista(),
  ];

  String get _rutaActiva => _rutas[_indiceActivo];

  void _navegar(String ruta) {
    final idx = _rutas.indexOf(ruta);
    if (idx < 0 || idx == _indiceActivo) return;
    setState(() {
      _indiceActivo = idx;
      _visitadas.add(idx);
    });
  }

  /// Qué permiso hace falta para ver cada sección del sidebar.
  ///
  /// Vive aparte de [_secciones] porque `ItemNavDato` es un DTO de
  /// presentación de share y no tiene por qué conocer el dominio: share
  /// pinta lo que le den, y quién puede ver qué lo decide esta capa.
  static const Map<String, Permiso> _permisoPorRuta = {
    '/venta': Permiso.posVer,
    '/productos': Permiso.productosVer,
    '/movimientos': Permiso.inventarioMovimientosVer,
    '/categorias': Permiso.categoriasVer,
    '/proveedores': Permiso.proveedoresVer,
    '/ordenes': Permiso.ordenesVer,
    '/cotizaciones': Permiso.cotizacionesVer,
    '/reservas': Permiso.reservasVer,
    '/tecnicos': Permiso.tecnicosVer,
    '/clientes': Permiso.clientesVer,
    '/deudores': Permiso.deudoresVer,
    '/bitacora': Permiso.bitacoraVer,
    '/configuracion': Permiso.configuracionVer,
    // `/dashboard` no lleva permiso: es la pantalla a la que cae quien no
    // tiene ninguna otra, y dejar a alguien sin sitio donde aterrizar es peor
    // que enseñarle un resumen vacío.
  };

  /// Los datos de navegación no dependen del estado: se arman una sola vez.
  /// Como getters, cada `build` creaba doce `ItemNavDato` con closures nuevas
  /// y obligaba a reconstruir todos los `ItemNav`.
  late final List<SeccionNavDato> _secciones = [
    SeccionNavDato(
      titulo: 'Principal',
      items: [
        ItemNavDato(
          icono: Icons.grid_view_rounded,
          etiqueta: 'Dashboard',
          ruta: '/dashboard',
          alPresionar: () => _navegar('/dashboard'),
        ),
        ItemNavDato(
          icono: Icons.point_of_sale_outlined,
          etiqueta: 'Punto de venta',
          ruta: '/venta',
          alPresionar: () => _navegar('/venta'),
        ),
        // Sin permiso a propósito: lo ven todos. Un cajero necesita poder
        // buscar la factura de un cliente que vuelve a reclamar.
        ItemNavDato(
          icono: Icons.receipt_long_outlined,
          etiqueta: 'Historial de ventas',
          ruta: '/historial-ventas',
          alPresionar: () => _navegar('/historial-ventas'),
        ),
      ],
    ),
    SeccionNavDato(
      titulo: 'Inventario',
      items: [
        ItemNavDato(
          icono: Icons.inventory_2_outlined,
          etiqueta: 'Productos',
          ruta: '/productos',
          alPresionar: () => _navegar('/productos'),
        ),
        ItemNavDato(
          icono: Icons.swap_vert_rounded,
          etiqueta: 'Movimientos',
          ruta: '/movimientos',
          alPresionar: () => _navegar('/movimientos'),
        ),
        ItemNavDato(
          icono: Icons.layers_outlined,
          etiqueta: 'Categorías',
          ruta: '/categorias',
          alPresionar: () => _navegar('/categorias'),
        ),
        ItemNavDato(
          icono: Icons.local_shipping_outlined,
          etiqueta: 'Proveedores',
          ruta: '/proveedores',
          alPresionar: () => _navegar('/proveedores'),
        ),
      ],
    ),
    SeccionNavDato(
      titulo: 'Taller',
      items: [
        ItemNavDato(
          icono: Icons.build_outlined,
          etiqueta: 'Órdenes de servicio',
          ruta: '/ordenes',
          alPresionar: () => _navegar('/ordenes'),
        ),
        ItemNavDato(
          icono: Icons.request_quote_outlined,
          etiqueta: 'Cotizaciones',
          ruta: '/cotizaciones',
          alPresionar: () => _navegar('/cotizaciones'),
        ),
        ItemNavDato(
          icono: Icons.bookmark_outline_rounded,
          etiqueta: 'Reservas',
          ruta: '/reservas',
          alPresionar: () => _navegar('/reservas'),
        ),
        ItemNavDato(
          icono: Icons.engineering_outlined,
          etiqueta: 'Técnicos',
          ruta: '/tecnicos',
          alPresionar: () => _navegar('/tecnicos'),
        ),
      ],
    ),
    SeccionNavDato(
      titulo: 'Clientes',
      items: [
        ItemNavDato(
          icono: Icons.people_outline_rounded,
          etiqueta: 'Clientes',
          ruta: '/clientes',
          alPresionar: () => _navegar('/clientes'),
        ),
        ItemNavDato(
          icono: Icons.attach_money_rounded,
          etiqueta: 'Cuentas por cobrar',
          ruta: '/deudores',
          alPresionar: () => _navegar('/deudores'),
        ),
      ],
    ),
    // La sección entera desaparece para quien no tenga `bitacoraVer`: la
    // recorta `_seccionesVisibles`, que no deja títulos sueltos sin ítems.
    SeccionNavDato(
      titulo: 'Administración',
      items: [
        ItemNavDato(
          icono: Icons.history_rounded,
          etiqueta: 'Bitácora',
          ruta: '/bitacora',
          alPresionar: () => _navegar('/bitacora'),
        ),
      ],
    ),
  ];

  late final List<ItemNavDato> _itemsInferiores = [
    ItemNavDato(
      icono: Icons.settings_outlined,
      etiqueta: 'Configuración',
      ruta: '/configuracion',
      alPresionar: () => _navegar('/configuracion'),
    ),
    ItemNavDato(
      icono: Icons.logout_outlined,
      etiqueta: 'Salir',
      ruta: '',
      alPresionar: _cerrarSesion,
    ),
  ];

  /// Se pregunta antes porque la sesión no se guarda: salir obliga a volver a
  /// teclear la contraseña, y el ítem está pegado al de Configuración.
  Future<void> _cerrarSesion() async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Cerrar sesión?',
      mensaje: 'Tendrás que volver a escribir tu usuario y tu contraseña.',
      textoConfirmar: 'Cerrar sesión',
      destructivo: false,
    );

    if (confirmado == true) ref.read(sesionProvider.notifier).salir();
  }

  /// Las secciones que esta cuenta puede ver.
  ///
  /// Se filtra en `build` y no una sola vez porque los permisos cambian en
  /// vivo: si el administrador le quita el mostrador a un cajero, el ítem
  /// tiene que irse sin que vuelva a entrar. Filtrar cuesta un `contains` por
  /// ítem sobre doce, y los `ItemNavDato` que sobreviven son **las mismas
  /// instancias**, así que sus `ItemNav` no se reconstruyen.
  List<SeccionNavDato> _seccionesVisibles(Set<Permiso> permisos) {
    final visibles = <SeccionNavDato>[];

    for (final seccion in _secciones) {
      final items = seccion.items.where((item) {
        final permiso = _permisoPorRuta[item.ruta];
        return permiso == null || permisos.contains(permiso);
      }).toList();

      // Una sección sin ítems visibles no deja su título suelto.
      if (items.isNotEmpty) {
        visibles.add(SeccionNavDato(titulo: seccion.titulo, items: items));
      }
    }

    return visibles;
  }

  @override
  Widget build(BuildContext context) {
    final permisos = ref.watch(permisosSesionProvider).value ?? const {};

    return Scaffold(
      backgroundColor: ColoresApp.bgApp,
      body: Row(
        children: [
          BarraLateral(
            secciones: _seccionesVisibles(permisos),
            itemsInferiores: _itemsInferiores
                .where((item) =>
                    item.ruta.isEmpty ||
                    _permisoPorRuta[item.ruta] == null ||
                    permisos.contains(_permisoPorRuta[item.ruta]))
                .toList(),
            rutaActiva: _rutaActiva,
          ),
          Expanded(
            child: RepaintBoundary(
              child: IndexedStack(
                index: _indiceActivo,
                children: [
                  for (var i = 0; i < _vistas.length; i++)
                    if (_visitadas.contains(i))
                      _vistas[i]
                    else
                      const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderVista extends StatelessWidget {
  const _PlaceholderVista({required this.etiqueta});

  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.construction_rounded,
            size: 48,
            color: ColoresApp.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(etiqueta, style: TipografiaApp.heading2),
          const SizedBox(height: 8),
          const Text('Vista en construcción', style: TipografiaApp.caption),
        ],
      ),
    );
  }
}
