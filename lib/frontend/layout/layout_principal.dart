import 'package:flutter/material.dart';

import '../features/categorias/vista/categorias_vistas.dart';
import '../features/clientes/vista/cliente_vista.dart';
import '../features/cotizaciones/vista/cotizaciones_vista.dart';
import '../features/deudores/vista/deudores_vista.dart';
import '../features/especializacion/vista/especializacion_vista.dart';
import '../features/motos/vista/motos_vista.dart';
import '../features/productos/vista/producto_vista.dart';
import '../features/proveedores/vista/proveedores_vista.dart';
import '../features/reservas/vista/reservas_vista.dart';
import '../features/tecnicos/vista/tecnico_vista.dart';
import '../features/unidades_medida/vista/unidad_medida_vista.dart';
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
  bool _sidebarExpandido = true;
  int _indiceActivo = 0;

  // Orden paralelo al IndexedStack — si se agrega una vista, va en ambos lugares
  static const List<String> _rutas = [
    '/dashboard',
    '/venta',
    '/productos',
    '/categorias',
    '/unidades-medida',
    '/proveedores',
    '/motos',
    '/cotizaciones',
    '/reservas',
    '/tecnicos',
    '/especializaciones',
    '/clientes',
    '/deudores',
  ];

  String get _rutaActiva => _rutas[_indiceActivo];

  void _navegar(String ruta) {
    final idx = _rutas.indexOf(ruta);
    if (idx >= 0) setState(() => _indiceActivo = idx);
  }

  List<SeccionNavDato> get _secciones => [
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
              icono: Icons.straighten_outlined,
              etiqueta: 'Unidades de medida',
              ruta: '/unidades-medida',
              alPresionar: () => _navegar('/unidades-medida'),
            ),
            ItemNavDato(
              icono: Icons.local_shipping_outlined,
              etiqueta: 'Proveedores',
              ruta: '/proveedores',
              alPresionar: () => _navegar('/proveedores'),
            ),
            ItemNavDato(
              icono: Icons.motorcycle_outlined,
              etiqueta: 'Motos',
              ruta: '/motos',
              alPresionar: () => _navegar('/motos'),
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
            ItemNavDato(
              icono: Icons.build_outlined,
              etiqueta: 'Especializaciones',
              ruta: '/especializaciones',
              alPresionar: () => _navegar('/especializaciones'),
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

  List<ItemNavDato> get _itemsInferiores => [
        ItemNavDato(
          icono: Icons.settings_outlined,
          etiqueta: 'Configuración',
          ruta: '/configuracion',
          alPresionar: () {},
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
          // ── Sidebar con animación de colapso ──────────────────────────────
          ClipRect(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              width: _sidebarExpandido ? 240.0 : 0.0,
              child: OverflowBox(
                maxWidth: 240,
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 240,
                  child: BarraLateral(
                    secciones: _secciones,
                    itemsInferiores: _itemsInferiores,
                    rutaActiva: _rutaActiva,
                  ),
                ),
              ),
            ),
          ),

          // ── Área de contenido ─────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  sidebarExpandido: _sidebarExpandido,
                  alToggle: () => setState(
                    () => _sidebarExpandido = !_sidebarExpandido,
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: ColoresApp.border),
                Expanded(
                  child: IndexedStack(
                    index: _indiceActivo,
                    children: const [
                      _PlaceholderVista(etiqueta: 'Dashboard'),
                      VentasVista(),
                      ProductosVista(),
                      CategoriasVista(),
                      UnidadesMedidaVista(),
                      ProveedoresVista(),
                      MotosVista(),
                      CotizacionesVista(),
                      ReservasVista(),
                      TecnicosVista(),
                      EspecializacionesVista(),
                      ClientesVista(),
                      DeudoresVista(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.sidebarExpandido, required this.alToggle});

  final bool sidebarExpandido;
  final VoidCallback alToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      color: ColoresApp.bgCard,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: sidebarExpandido ? 'Ocultar menú' : 'Mostrar menú',
            icon: Icon(
              sidebarExpandido ? Icons.menu_open_rounded : Icons.menu_rounded,
              size: 20,
              color: ColoresApp.textSecondary,
            ),
            onPressed: alToggle,
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
          Text('Vista en construcción', style: TipografiaApp.caption),
        ],
      ),
    );
  }
}
