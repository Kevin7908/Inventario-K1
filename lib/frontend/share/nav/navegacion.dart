import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/features/cotizaciones/vista/cotizaciones_vista.dart';
import 'package:inventario_k1/frontend/features/tecnicos/vista/tecnico_vista.dart';
import 'package:inventario_k1/frontend/features/ventas/principal/vista/venta_vista.dart';
import 'package:inventario_k1/frontend/share/nav/nav_section.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/widgets/barra_lateral_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/placeholder_widget.dart';

import '../../features/categorias/vista/categorias_vistas.dart';
import '../../features/clientes/vista/cliente_vista.dart';
import '../../features/especializacion/vista/especializacion_vista.dart';
import '../../features/motos/vista/motos_vista.dart';
import '../../features/productos/vista/producto_vista.dart';
import '../../features/proveedores/vista/proveedores_vista.dart';
import '../../features/unidades_medida/vista/unidad_medida_vista.dart';

class Navegacion extends StatefulWidget {
  const Navegacion({super.key});

  @override
  State<Navegacion> createState() => _NavegacionState();
}

class _NavegacionState extends State<Navegacion> {
  NavSection _seccionActual = NavSection.dashboard;

  // El orden DEBE coincidir exactamente con los children del IndexedStack
  static const List<NavSection> _navOrder = [
    NavSection.dashboard,
    NavSection.productos,
    NavSection.categorias,
    NavSection.unidadesMedida,
    NavSection.vender,
    NavSection.cotizaciones,
    NavSection.deudores,
    NavSection.clientes,
    NavSection.proveedores,
    NavSection.motos,
    NavSection.tecnicos,
    NavSection.especializaciones,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          BarraLateralWidget(
            seccionActual: _seccionActual,
            cambioSeccion: (section) =>
                setState(() => _seccionActual = section),
          ),
          const VerticalDivider(
            width: 1,
            thickness: 1,
            color: ColoresApp.borderSidebar,
          ),
          Expanded(
            child: IndexedStack(
              index: _navOrder.indexOf(_seccionActual),
              children: const [
                PlaceholderWidget(seccion: NavSection.dashboard),
                ProductosVista(),
                CategoriasVista(),
                UnidadesMedidaVista(),
                VentasVista(),
                CotizacionesVista(),
                PlaceholderWidget(seccion: NavSection.deudores),
                ClientesVista(),
                ProveedoresVista(),
                MotosVista(),
                TecnicosVista(),
                EspecializacionesVista(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
