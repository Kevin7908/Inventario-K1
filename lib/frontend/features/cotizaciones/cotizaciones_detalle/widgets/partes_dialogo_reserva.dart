import 'package:flutter/material.dart';

import '../../../../../backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import '../../../../../core/formato.dart';
import '../../../../share2/share2.dart';

class EncabezadoReserva extends StatelessWidget {
  const EncabezadoReserva({
    super.key,
    required this.numero,
    required this.alCerrar,
  });

  final String numero;
  final VoidCallback? alCerrar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      decoration: const BoxDecoration(
        color: ColoresApp.bgInput,
        border: Border(bottom: BorderSide(color: ColoresApp.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Crear reserva', style: TipografiaApp.heading3),
                const SizedBox(height: 2),
                Text(
                  'Desde la cotización $numero',
                  style: TipografiaApp.subtituloPagina,
                ),
              ],
            ),
          ),
          BotonIcono(
            icono: Icons.close_rounded,
            tooltip: 'Cerrar',
            alPresionar: alCerrar,
          ),
        ],
      ),
    );
  }
}

/// Qué se va a reservar, para confirmar antes de comprometer inventario.
class ResumenReserva extends StatelessWidget {
  const ResumenReserva({
    super.key,
    required this.cotizacion,
    required this.productos,
    required this.totalReserva,
  });

  final CotizacionResumen cotizacion;
  final int productos;
  final int totalReserva;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresApp.bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.border),
      ),
      child: Column(
        children: [
          FilaDato(
            icono: Icons.person_outline_rounded,
            texto: cotizacion.nombreCliente,
          ),
          if (cotizacion.nombreMoto.isNotEmpty) ...[
            const SizedBox(height: 8),
            FilaDato(
              icono: Icons.two_wheeler_rounded,
              texto: cotizacion.nombreMoto,
            ),
          ],
          const SizedBox(height: 8),
          FilaDato(
            icono: Icons.inventory_2_outlined,
            texto: productos == 1
                ? '1 producto para reservar'
                : '$productos productos para reservar',
          ),
          const SizedBox(height: 12),
          const Divider(color: ColoresApp.border, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total a reservar', style: TipografiaApp.caption),
              Text(
                formatearPrecio(totalReserva),
                style: TipografiaApp.cuerpoMedium.copyWith(
                  color: ColoresApp.castletonGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
