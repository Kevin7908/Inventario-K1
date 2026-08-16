import 'package:flutter/material.dart';

import '../features/categorias/vista/categorias_vistas.dart';
import '../features/clientes/vista/cliente_vista.dart';
import '../features/configuracion/vista/configuracion_vista.dart';
import '../features/cotizaciones/vista/cotizaciones_vista.dart';
import '../features/deudores/vista/deudores_vista.dart';
import '../features/productos/vista/producto_vista.dart';
import '../features/proveedores/vista/proveedores_vista.dart';
import '../features/reservas/vista/reservas_vista.dart';
import '../features/tecnicos/vista/tecnico_vista.dart';
import '../features/ventas/principal/vista/venta_vista.dart';
import '../share2/nav/barra_lateral.dart';
import '../share2/nav/item_nav_dato.dart';
import '../share2/nav/seccion_nav_dato.dart';
import '../share2/temas/colores_app.dart';
import '../share2/temas/tipografia_app.dart';

class LayoutPrincipal extends StatefulWidget {
  const LayoutPrincipal({super.key});

  @override
  State<LayoutPrincipal> createState() => _LayoutPrincipalState();
}

class _LayoutPrincipalState extends State<LayoutPrincipal> {
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
    '/productos',
    '/categorias',
    '/proveedores',
    '/cotizaciones',
    '/reservas',
    '/tecnicos',
    '/clientes',
    '/deudores',
    '/configuracion',
  ];

  /// Vistas en el mismo orden que [_rutas]. `const`, así que la lista no cuesta
  /// nada: lo que cuesta es construirlas, y eso solo pasa al visitarlas.
  static const List<Widget> _vistas = [
    _PlaceholderVista(etiqueta: 'Dashboard'),
    VentasVista(),
    ProductosVista(),
    CategoriasVista(),
    ProveedoresVista(),
    CotizacionesVista(),
    ReservasVista(),
    TecnicosVista(),
    ClientesVista(),
    DeudoresVista(),
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
      alPresionar: () {},
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.bgApp,
      body: Row(
        children: [
          BarraLateral(
            secciones: _secciones,
            itemsInferiores: _itemsInferiores,
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
