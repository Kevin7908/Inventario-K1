import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../share/temas/colores_app.dart';
import '../../facturas/vista/facturas_vista.dart';
import '../../ordenes/vista/ordenes_vista.dart';
import '../../servicios/vista/servicio_vista.dart';
import '../../venta_rapida/vista/venta_rapida_vista.dart';

// Acentos por tab — igual que HTML de guía.
const _kAcentoOrdenes   = ColoresApp.primary;       // blue
const _kAcentoServicios = ColoresApp.accentGreen;    // green
const _kAcentoFactura   = ColoresApp.accentAmber;    // amber
const _kAcentoRapida    = ColoresApp.accentPurple;   // purple

class _TabDef {
  const _TabDef({
    required this.label,
    required this.icono,
    required this.acento,
  });
  final String   label;
  final IconData icono;
  final Color    acento;
}

const _tabs = [
  _TabDef(label: 'Órdenes',      icono: Icons.build_outlined,              acento: _kAcentoOrdenes),
  _TabDef(label: 'Servicios',    icono: Icons.home_repair_service_outlined, acento: _kAcentoServicios),
  _TabDef(label: 'Facturación',  icono: Icons.request_quote_outlined,       acento: _kAcentoFactura),
  _TabDef(label: 'Venta Rápida', icono: Icons.bolt_outlined,                acento: _kAcentoRapida),
];

class VentasVista extends ConsumerStatefulWidget {
  const VentasVista({super.key});

  @override
  ConsumerState<VentasVista> createState() => _VentasVistaState();
}

class _VentasVistaState extends ConsumerState<VentasVista>
    with SingleTickerProviderStateMixin {
  late final TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: _tabs.length, vsync: this);
    _tc.addListener(_rebuild);
  }

  void _rebuild() {
    if (!_tc.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tc
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.bgContent,
      body: Column(
        children: [
          // ── Top bar ──────────────────────────────────────────────────────
          Container(
            color: ColoresApp.bgCard,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
            child: Row(
              children: [
                const Text(
                  'Ventas',
                  style: TextStyle(
                    color: ColoresApp.textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                _PillTabBar(tc: _tc),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: ColoresApp.border),
          // ── Cuerpo ───────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tc,
              physics: const NeverScrollableScrollPhysics(),
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

// ── Pill tab bar ──────────────────────────────────────────────────────────────

class _PillTabBar extends StatelessWidget {
  const _PillTabBar({required this.tc});
  final TabController tc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_tabs.length, (i) {
          final tab = _tabs[i];
          final sel = tc.index == i;
          return _TabPill(
            tab:         tab,
            seleccionado: sel,
            onTap:       () => tc.animateTo(i),
          );
        }),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.tab,
    required this.seleccionado,
    required this.onTap,
  });

  final _TabDef       tab;
  final bool          seleccionado;
  final VoidCallback  onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: seleccionado ? tab.acento : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: seleccionado
              ? [
                  BoxShadow(
                    color: tab.acento.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
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
              color: seleccionado ? Colors.white : ColoresApp.textMedium,
            ),
            const SizedBox(width: 6),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: seleccionado ? Colors.white : ColoresApp.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
