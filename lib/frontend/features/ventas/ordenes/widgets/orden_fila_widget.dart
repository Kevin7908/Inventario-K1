import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import '../../../../../backend/features/ventas/ordenes/enum/enum_ordenes.dart';
import '../../../../../backend/features/ventas/ordenes/modelo/orden_resumen.dart';
import '../../../../share/widgets/botones/accion_boton.dart';

String _fmtMoneda(int monto) {
  String valor = monto.abs().toStringAsFixed(2);
  List<String> partes = valor.split('.');
  String entera = partes[0];
  String decimal = partes[1];

  // Insertar comas en los miles
  entera = entera.replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
    (Match m) => '${m[1]},'
  );

  return "${monto < 0 ? '-' : ''}\$ $entera.$decimal";
}
String _fmtFecha(DateTime fecha) {
  // padLeft(2, '0') asegura que si el día es 5, se vea como 05
  String dia = fecha.day.toString().padLeft(2, '0');
  String mes = fecha.month.toString().padLeft(2, '0');
  String anio = fecha.year.toString();
  
  return "$dia/$mes/$anio";
}

class BadgeEstadoOrden extends StatelessWidget {
  const BadgeEstadoOrden({super.key, required this.estado});

  final EstadoOrden estado;

  @override
  Widget build(BuildContext context) {
    final (label, color, textColor) = switch (estado) {
      EstadoOrden.abierta => (
        'Abierta',
        ColoresApp.bgContent,
        ColoresApp.primary,
      ),
      EstadoOrden.lista => (
        'Lista',
        const Color(0xFFDCFCE7),
        const Color(0xFF166534),
      ),
      EstadoOrden.entregada => (
        'Entregada',
        const Color(0xFFF3F4F6),
        const Color(0xFF374151),
      ),
      EstadoOrden.anulada => (
        'Anulada',
        const Color(0xFFFEE2E2),
        const Color(0xFF991B1B),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: textColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class OrdenFilaWidget extends StatelessWidget {
  const OrdenFilaWidget({
    super.key,
    required this.orden,
    required this.onTap,
    required this.onEditar,
    required this.onEliminar,
  });

  final OrdenResumen orden;
  final VoidCallback onTap;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
        ),
        child: Row(
          children: [
            // #ORDEN
            SizedBox(
              width: 100,
              child: Text(
                orden.numeroOrden,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                ),
              ),
            ),
            // MOTO
            Expanded(
              flex: 3,
              child: Text(
                orden.motoDescripcion,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // CLIENTE
            Expanded(
              flex: 2,
              child: Text(
                orden.clienteNombre,
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // KM
            SizedBox(
              width: 100,
              child: Text(
                _fmtMoneda(orden.kilometrajeEntrada),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
                textAlign: TextAlign.right,
              ),
            ),
            // DIAGNÓSTICO
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  orden.diagnostico ?? '—',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
            // INGRESO — ahora es DateTime?
            SizedBox(
              width: 80,
              child: Text(
                orden.fechaIngreso != null
                    ? _fmtFecha(orden.fechaIngreso!)
                    : '—',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF9CA3AF),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // ESTADO
            SizedBox(
              width: 100,
              child: Center(child: BadgeEstadoOrden(estado: orden.estado)),
            ),
            // ACCIONES
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 8),
                AccionBoton(
                  icono: Icons.edit_outlined,
                  tooltip: 'Editar orden',
                  alPresionar: onEditar,
                ),
                const SizedBox(width: 6),
                AccionBoton(
                  icono: Icons.delete_outline_rounded,
                  tooltip: 'Eliminar orden',
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

class OrdenTablaEncabezado extends StatelessWidget {
  const OrdenTablaEncabezado({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
        ),
      ),
      child: Row(
        children: const [
          SizedBox(width: 100, child: _EncHeader('#ORDEN')),
          Expanded(flex: 3, child: _EncHeader('MOTO')),
          Expanded(flex: 2, child: _EncHeader('CLIENTE')),
          SizedBox(width: 100, child: _EncHeader('KM ENTRADA', right: true)),
          Expanded(
            flex: 3,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _EncHeader('DIAGNÓSTICO'),
            ),
          ),
          SizedBox(width: 80, child: _EncHeader('INGRESO', center: true)),
          SizedBox(width: 100, child: _EncHeader('ESTADO', center: true)),
          SizedBox(width: 80, child: _EncHeader('ACCIONES', center: true)),
        ],
      ),
    );
  }
}

class _EncHeader extends StatelessWidget {
  const _EncHeader(this.label, {this.right = false, this.center = false});
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
