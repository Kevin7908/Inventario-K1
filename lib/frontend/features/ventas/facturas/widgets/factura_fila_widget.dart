import 'package:flutter/material.dart';

import '../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../../../../backend/features/ventas/facturas/modelo/factura_resumen.dart';
import '../../../../share/formateadores/moneda_formateador.dart';
import '../../../../share/temas/colores_app.dart';
import '../../../../share/widgets/botones/accion_boton.dart';

String _fmtFecha(DateTime? f) {
  if (f == null) return '—';
  return '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
}

class FacturaFilaWidget extends StatelessWidget {
  const FacturaFilaWidget({
    super.key,
    required this.factura,
    required this.onTap,
    required this.onEliminar,
  });

  final FacturaResumen factura;
  final VoidCallback onTap;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
        ),
        child: Row(
          children: [
            // Número factura
            SizedBox(
              width: 110,
              child: Text(
                factura.numeroFactura,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: ColoresApp.textDark,
                ),
              ),
            ),
            // Tipo
            SizedBox(
              width: 95,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _BadgeTipo(tipo: factura.tipo),
              ),
            ),
            // Cliente
            Expanded(
              flex: 2,
              child: Text(
                factura.clienteNombre,
                style: const TextStyle(fontSize: 13, color: ColoresApp.textDark),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Orden
            SizedBox(
              width: 95,
              child: Text(
                factura.numeroOrden ?? '—',
                style: const TextStyle(
                  fontSize: 13,
                  color: ColoresApp.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Total
            SizedBox(
              width: 100,
              child: Text(
                fmtMoneda(factura.total),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.textDark,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Estado pago
            SizedBox(
              width: 95,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _BadgeEstadoPago(estado: factura.estadoPago),
              ),
            ),
            // Método
            SizedBox(
              width: 105,
              child: Text(
                factura.metodoPago.etiqueta,
                style: const TextStyle(fontSize: 12, color: ColoresApp.textMedium),
              ),
            ),
            // Fecha
            SizedBox(
              width: 95,
              child: Text(
                _fmtFecha(factura.creadoEn),
                style: const TextStyle(fontSize: 12, color: ColoresApp.textLight),
              ),
            ),
            // Acciones
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 8),
                AccionBoton(
                  icono: Icons.visibility_outlined,
                  tooltip: 'Ver detalle',
                  alPresionar: onTap,
                ),
                const SizedBox(width: 6),
                AccionBoton(
                  icono: Icons.delete_outline_rounded,
                  tooltip: 'Eliminar factura',
                  esDestructivo: true,
                  alPresionar: onEliminar,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FacturaTablaEncabezado extends StatelessWidget {
  const FacturaTablaEncabezado({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1.5)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 110, child: _Enc('FACTURA')),
          SizedBox(width: 95, child: _Enc('TIPO')),
          Expanded(flex: 2, child: _Enc('CLIENTE')),
          SizedBox(width: 95, child: _Enc('ORDEN')),
          SizedBox(width: 100, child: _Enc('TOTAL', right: true)),
          SizedBox(width: 12),
          SizedBox(width: 95, child: _Enc('ESTADO')),
          SizedBox(width: 105, child: _Enc('MÉTODO')),
          SizedBox(width: 95, child: _Enc('FECHA')),
          SizedBox(width: 80, child: _Enc('ACCIONES', center: true)),
        ],
      ),
    );
  }
}

class _Enc extends StatelessWidget {
  const _Enc(this.label, {this.right = false, this.center = false});
  final String label;
  final bool right;
  final bool center;

  @override
  Widget build(BuildContext context) => Text(
        label,
        textAlign: right
            ? TextAlign.right
            : center
                ? TextAlign.center
                : TextAlign.left,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9CA3AF),
          letterSpacing: 0.5,
        ),
      );
}

class _BadgeTipo extends StatelessWidget {
  const _BadgeTipo({required this.tipo});
  final TipoVenta tipo;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (tipo) {
      TipoVenta.servicio  => ('Servicio', ColoresApp.primary),
      TipoVenta.mostrador => ('Mostrador', ColoresApp.accentTeal),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _BadgeEstadoPago extends StatelessWidget {
  const _BadgeEstadoPago({required this.estado});
  final EstadoPago estado;

  @override
  Widget build(BuildContext context) {
    final (color, textColor) = switch (estado) {
      EstadoPago.pagado   => (const Color(0xFFD1FAE5), const Color(0xFF065F46)),
      EstadoPago.pendiente => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      EstadoPago.anulada  => (const Color(0xFFFEE2E2), const Color(0xFF991B1B)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(
        estado.etiqueta,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
