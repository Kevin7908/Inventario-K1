import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/share/nav/nav_section.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/widgets/barra_lateral_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/placeholder_widget.dart';

import '../../features/categorias/vista/categorias_vistas.dart';
import '../../features/clientes/vista/cliente_vista.dart';
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
    NavSection.vender,
    NavSection.deudores,
    NavSection.clientes,
    NavSection.proveedores,
    NavSection.unidadesMedida,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Menú lateral
          BarraLateralWidget(
            seccionActual: _seccionActual,
            cambioSeccion: (section) =>
                setState(() => _seccionActual = section),
          ),

          // Separador visual
          const VerticalDivider(
            width: 1,
            thickness: 1,
            color: ColoresApp.borderSidebar,
          ),

          // Contenido principal — IndexedStack mantiene el estado de cada vista
          Expanded(
            child: IndexedStack(
              index: _navOrder.indexOf(_seccionActual),
              children: const [
                PlaceholderWidget(seccion: NavSection.dashboard),
                ProductosVista(),
                // Las vistas reales que ya tienen lógica MVVM:
                CategoriasVista(),
                PlaceholderWidget(seccion: NavSection.vender),
                PlaceholderWidget(seccion: NavSection.deudores),
                ClientesVista(),
                ProveedoresVista(),
                UnidadesMedidaVista(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
