import 'package:flutter/material.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/widgets/botones/accion_boton.dart';

import 'package:inventario_k1/backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import 'badge_estado_cotizacion.dart';

// ── Encabezado de la tabla ────────────────────────────────────────────────────

class CotizacionTablaEncabezado extends StatelessWidget {
  const CotizacionTablaEncabezado({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ColoresApp.border)),
      ),
      child: const Row(
        children: [
          _EncabezadoCol(label: 'NÚMERO', flex: 2),
          _EncabezadoCol(label: 'CLIENTE', flex: 3),
          _EncabezadoCol(label: 'MOTO', flex: 3),
          _EncabezadoCol(label: 'TOTAL', flex: 2),
          _EncabezadoCol(label: 'VIGENCIA', flex: 2),
          _EncabezadoCol(label: 'ESTADO', flex: 2),
          _EncabezadoCol(label: 'ACCIONES', flex: 2, alinear: TextAlign.end),
        ],
      ),
    );
  }
}

class _EncabezadoCol extends StatelessWidget {
  const _EncabezadoCol({
    required this.label,
    required this.flex,
    this.alinear = TextAlign.start,
  });

  final String label;
  final int flex;
  final TextAlign alinear;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: alinear,
        style: const TextStyle(
          color: ColoresApp.textLight,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── Fila de cotización ────────────────────────────────────────────────────────

class CotizacionFilaWidget extends StatefulWidget {
  const CotizacionFilaWidget({
    super.key,
    required this.cotizacion,
    required this.seleccionada,
    required this.onTap,
    required this.onEditar,
    required this.onEliminar,
  });

  final CotizacionResumen cotizacion;
  final bool seleccionada;
  final VoidCallback onTap;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  State<CotizacionFilaWidget> createState() => _CotizacionFilaWidgetState();
}

class _CotizacionFilaWidgetState extends State<CotizacionFilaWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.cotizacion;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: widget.seleccionada
              ? ColoresApp.primaryLight
              : _hovered
                  ? ColoresApp.bgCardHover
                  : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              // Número
              Expanded(
                flex: 2,
                child: Text(
                  c.numero,
                  style: const TextStyle(
                    color: ColoresApp.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Cliente
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.nombreCliente,
                      style: const TextStyle(
                        color: ColoresApp.textDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (c.telefonoCliente != null)
                      Text(
                        c.telefonoCliente!,
                        style: const TextStyle(
                          color: ColoresApp.textLight,
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                ),
              ),

              // Moto
              Expanded(
                flex: 3,
                child: _MotoChip(nombreMoto: c.nombreMoto),
              ),

              // Total — usa toCompactCop() para evitar recálculo en cada build
              Expanded(
                flex: 2,
                child: Text(
                  c.total.toCompactCop(),
                  style: const TextStyle(
                    color: ColoresApp.textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Vigencia
              Expanded(
                flex: 2,
                child: Text(
                  c.vigenciaHasta,
                  style: const TextStyle(
                    color: ColoresApp.textMedium,
                    fontSize: 13,
                  ),
                ),
              ),

              // Estado
              Expanded(
                flex: 2,
                child: BadgeEstadoCotizacion(estado: c.estado),
              ),

              // Acciones
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AccionBoton(
                      icono: Icons.edit_outlined,
                      tooltip: 'Editar',
                      alPresionar: widget.onEditar,
                    ),
                    const SizedBox(width: 6),
                    AccionBoton(
                      icono: Icons.delete_outline_rounded,
                      tooltip: 'Eliminar',
                      esDestructivo: true,
                      alPresionar: widget.onEliminar,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MotoChip extends StatelessWidget {
  const _MotoChip({required this.nombreMoto});

  final String nombreMoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ColoresApp.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColoresApp.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.two_wheeler_rounded,
              size: 12, color: ColoresApp.primary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              nombreMoto,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ColoresApp.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
