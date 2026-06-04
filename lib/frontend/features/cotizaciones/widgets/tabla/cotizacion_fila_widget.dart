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

class CotizacionFilaWidget extends StatelessWidget {
  const CotizacionFilaWidget({
    super.key,
    required this.cotizacion,
    required this.seleccionada,
    required this.onTap,
    required this.onEliminar,
  });

  final CotizacionResumen cotizacion;
  final bool seleccionada;
  final VoidCallback onTap;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final c = cotizacion;

    return Row(
      children: [
        // ── Zona de datos clickable ──────────────────────────────
        Expanded(
          flex: 14,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 0, 14),
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
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _MotoChip(nombreMoto: c.nombreMoto),
                    ),
                  ),

                  // Total
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
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: BadgeEstadoCotizacion(estado: c.estado),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Botón eliminar ───────────────────────────────────────
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AccionBoton(
                  icono: Icons.delete_outline_rounded,
                  tooltip: 'Eliminar',
                  esDestructivo: true,
                  alPresionar: onEliminar,
                ),
              ],
            ),
          ),
        ),
      ],
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
