import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/frontend/features/ventas/ordenes/vista/ordenes_vista.dart';

import '../../../../share/temas/colores_app.dart';
import '../../facturas/vista/facturas_vista.dart';
import '../../servicios/vista/servicio_vista.dart';
import '../../venta_rapida/vista/venta_rapida_vista.dart';

class VentasVista extends ConsumerStatefulWidget {
  const VentasVista({super.key});

  @override
  ConsumerState<VentasVista> createState() => _VentasVistaState();
}

class _VentasVistaState extends ConsumerState<VentasVista>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    _TabDef(label: 'Ordenes', icono: Icons.receipt_long_outlined),
    _TabDef(label: 'Servicios', icono: Icons.home_repair_service_outlined),
    _TabDef(label: 'Facturación', icono: Icons.request_quote_outlined),
    _TabDef(label: 'Venta Rápida', icono: Icons.point_of_sale_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this); // 4 tabs
    // Escuchamos el cambio de índice para actualizar el color de los botones
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.bgContent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera del modulo
          Container(
            color: ColoresApp.bgCard,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                const Text(
                  'Ventas',
                  style: TextStyle(
                    color: ColoresApp.textDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),

                // TabBar pill
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: ColoresApp.bgContent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ColoresApp.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_tabs.length, (i) {
                      final tab = _tabs[i];
                      final sel = _tabController.index == i;
                      return GestureDetector(
                        onTap: () => setState(() => _tabController.index = i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: sel ? ColoresApp.bgCard : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: sel
                                ? Border.all(color: ColoresApp.border)
                                : Border.all(color: Colors.transparent),
                            boxShadow: sel
                                ? [
                                    const BoxShadow(
                                      color: ColoresApp.shadow,
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tab.icono,
                                size: 14,
                                color: sel
                                    ? ColoresApp.primary
                                    : ColoresApp.textMedium,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tab.label,
                                style: TextStyle(
                                  color: sel
                                      ? ColoresApp.textDark
                                      : ColoresApp.textMedium,
                                  fontSize: 13,
                                  fontWeight: sel
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: ColoresApp.border),
          Expanded(
            child: IndexedStack(
              index: _tabController.index,
              children: const [
                OrdenesVista(),
                ServiciosVista(),
                FacturasVista(),
                VentaRapidaVista(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabDef {
  final String label;
  final IconData icono;
  const _TabDef({required this.label, required this.icono});
}

