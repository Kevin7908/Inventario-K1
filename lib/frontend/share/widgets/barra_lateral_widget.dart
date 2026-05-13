import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/share/nav/nav_section.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/widgets/perfil_usuario_widget.dart';

class BarraLateralWidget extends StatelessWidget {
  final NavSection seccionActual;
  final ValueChanged<NavSection> cambioSeccion;

  const BarraLateralWidget({
    super.key,
    required this.seccionActual,
    required this.cambioSeccion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: ColoresApp.bgSidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLogo(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSectionLabel('PRINCIPAL'),
                _buildNavItem(
                  NavSection.dashboard,
                  Icons.grid_view_rounded,
                  'Dashboard',
                ),
                _buildNavItem(
                  NavSection.productos,
                  Icons.inventory_2_outlined,
                  'Productos',
                ),
                _buildNavItem(
                  NavSection.categorias,
                  Icons.layers_outlined,
                  'Categorías',
                ),
                const SizedBox(height: 8),
                _buildSectionLabel('COMERCIAL'),
                _buildNavItem(
                  NavSection.vender,
                  Icons.shopping_cart_outlined,
                  'Vender',
                ),
                _buildNavItem(
                  NavSection.deudores,
                  Icons.attach_money_rounded,
                  'Deudores',
                ),
                const SizedBox(height: 8),
                _buildSectionLabel('GESTIÓN'),
                _buildNavItem(
                  NavSection.clientes,
                  Icons.people_outline_rounded,
                  'Clientes',
                ),
                _buildNavItem(
                  NavSection.proveedores,
                  Icons.local_shipping_outlined,
                  'Proveedores',
                ),
                _buildNavItem(
                  NavSection.unidadesMedida,
                  Icons.straighten_outlined,
                  'Unidades Medida',
                ),
                _buildNavItem(
                  NavSection.motos,
                  Icons.motorcycle_outlined,
                  'Motos',
                ),
                _buildNavItem(
                  NavSection.especializaciones,
                  Icons.build_outlined,
                  'Especializaciones',
                ),
              ],
            ),
          ),
          PerfilUsuarioWidget(nombre: 'Kevin Quintero', rol: 'Administrador'),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ColoresApp.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.grid_view_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MotoStock',
                style: TextStyle(
                  color: ColoresApp.textWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                'Taller & Inventario',
                style: TextStyle(
                  color: ColoresApp.textSidebarMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        label,
        style: const TextStyle(
          color: ColoresApp.textSidebarMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildNavItem(NavSection section, IconData icon, String label) {
    final isActive = seccionActual == section;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: InkWell(
        onTap: () => cambioSeccion(section),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isActive ? ColoresApp.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? ColoresApp.textWhite : ColoresApp.textSidebar,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? ColoresApp.textWhite
                      : ColoresApp.textSidebar,
                  fontSize: 13.5,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
