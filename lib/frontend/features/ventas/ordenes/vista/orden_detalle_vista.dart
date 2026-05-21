import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../backend/features/ventas/ordenes/enum/enum_ordenes.dart';
import '../../../../../backend/features/ventas/ordenes/modelo/orden_detalle.dart';
import '../../../../../backend/features/ventas/ordenes/modelo/orden_repuesto.dart';
import '../../../../../backend/features/ventas/ordenes/modelo/orden_tarea.dart';
import '../../../../share/widgets/botones/accion_boton.dart';
import '../../../../share/widgets/botones/dialogo_confirmar_eliminar_widget.dart';
import '../../../../share/widgets/output/estado_error_widget.dart';
import '../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../provider/ordenes_provider.dart';
import '../widgets/orden_fila_widget.dart';

final _fmtMoneda = NumberFormat('\$#,##0.00', 'es_CO');
final _fmtFecha = DateFormat('d \'de\' MMMM \'de\' yyyy  -  HH:mm', 'es_CO');

class OrdenDetalleVista extends ConsumerWidget {
  const OrdenDetalleVista({super.key, required this.ordenId});

  final int ordenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalleAsync = ref.watch(ordenDetalleProvider(ordenId));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: detalleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EstadoErrorWidget(
          mensaje: e.toString(),
          alReintentar: () => ref.invalidate(ordenDetalleProvider(ordenId)),
        ),
        data: (detalle) => _ContenidoDetalle(detalle: detalle),
      ),
    );
  }
}

class _ContenidoDetalle extends ConsumerWidget {
  const _ContenidoDetalle({required this.detalle});

  final OrdenDetalle detalle;

  void _confirmarEliminar(BuildContext context, WidgetRef ref) {
    DialogoConfirmarEliminar.mostrar(
      context: context,
      nombreElemento: detalle.numeroOrden,
      tipoElemento: 'orden',
      onConfirmar: () async {
        final error = await ref
            .read(ordenesProvider.notifier)
            .eliminar(detalle.id);
        if (!context.mounted) return;
        if (error != null) {
          SnackBarMensaje.error(context, error);
        } else {
          Navigator.of(context).pop(); // volver a la lista
          SnackBarMensaje.success(context, 'Orden eliminada');
        }
      },
    );
  }

  Future<void> _cambiarEstado(
    BuildContext context,
    WidgetRef ref,
    EstadoOrden nuevo,
  ) async {
    final error = await ref
        .read(ordenesProvider.notifier)
        .cambiarEstado(detalle.id, nuevo);
    if (!context.mounted) return;
    if (error != null) {
      SnackBarMensaje.error(context, error);
    } else {
      ref.invalidate(ordenDetalleProvider(detalle.id));
      SnackBarMensaje.success(context, 'Estado cambiado a ${nuevo.etiqueta}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _DetalleTopBar(
          detalle: detalle,
          onVolver: () => Navigator.of(context).pop(),
          onEliminar: () => _confirmarEliminar(context, ref),
          onCambiarEstado: (nuevo) => _cambiarEstado(context, ref, nuevo),
        ),
        // Cuerpo con scroll
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Fila: info orden + info moto/cliente
                _FilaInfoSuperior(detalle: detalle),
                const SizedBox(height: 24),
                // Tareas y repuestos en dos columnas
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _TarjeTareas(tareas: detalle.tareas)),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _TarjetaRepuestos(repuestos: detalle.repuestos),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Resumen de totales
                _TarjetaTotales(detalle: detalle),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Top bar del detalle

class _DetalleTopBar extends StatelessWidget {
  const _DetalleTopBar({
    required this.detalle,
    required this.onVolver,
    required this.onEliminar,
    required this.onCambiarEstado,
  });

  final OrdenDetalle detalle;
  final VoidCallback onVolver;
  final VoidCallback onEliminar;
  final ValueChanged<EstadoOrden> onCambiarEstado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          // Botón volver
          AccionBoton(
            icono: Icons.arrow_back_ios_new_rounded,
            tooltip: 'Volver',
            alPresionar: onVolver,
          ),
          const SizedBox(width: 16),
          // Título
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detalle.numeroOrden,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  detalle.motoDescripcion,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          // Badge estado
          BadgeEstadoOrden(estado: detalle.estado),
          const SizedBox(width: 16),
          // Cambiar estado (desplegable)
          _MenuCambiarEstado(
            estadoActual: detalle.estado,
            onCambiar: onCambiarEstado,
          ),
          const SizedBox(width: 8),
          // Eliminar
          AccionBoton(
            icono: Icons.delete_outline_rounded,
            tooltip: 'Eliminar orden',
            esDestructivo: true,
            alPresionar: onEliminar,
          ),
        ],
      ),
    );
  }
}

class _MenuCambiarEstado extends StatelessWidget {
  const _MenuCambiarEstado({
    required this.estadoActual,
    required this.onCambiar,
  });

  final EstadoOrden estadoActual;
  final ValueChanged<EstadoOrden> onCambiar;

  @override
  Widget build(BuildContext context) {
    final opciones = EstadoOrden.values
        .where((e) => e != estadoActual)
        .toList();

    return PopupMenuButton<EstadoOrden>(
      tooltip: 'Cambiar estado',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => opciones
          .map((e) => PopupMenuItem(value: e, child: Text(e.etiqueta)))
          .toList(),
      onSelected: onCambiar,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cambiar estado',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 16, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }
}

class _FilaInfoSuperior extends StatelessWidget {
  const _FilaInfoSuperior({required this.detalle});

  final OrdenDetalle detalle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info de la orden
        Expanded(
          child: _TarjetaInfo(
            titulo: 'Información de la Orden',
            icono: Icons.assignment_outlined,
            items: [
              _InfoItem('N° Orden', detalle.numeroOrden),
              _InfoItem(
                'Fecha ingreso',
                detalle.fechaIngreso != null
                    ? _fmtFecha.format(detalle.fechaIngreso!)
                    : '—',
              ),
              _InfoItem(
                'Fecha salida',
                detalle.fechaSalida != null
                    ? _fmtFecha.format(detalle.fechaSalida!)
                    : '—',
              ),
              _InfoItem(
                'Km entrada',
                NumberFormat(
                  '#,##0',
                  'es_CO',
                ).format(detalle.kilometrajeEntrada),
              ),
              _InfoItem(
                'Diagnóstico (cliente)',
                detalle.diagnosticoCliente ?? '—',
              ),
              _InfoItem(
                'Observaciones (mecánico)',
                detalle.observacionesMecanico ?? '—',
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        // Info de moto y cliente
        Expanded(
          child: _TarjetaInfo(
            titulo: 'Moto y Cliente',
            icono: Icons.two_wheeler_outlined,
            items: [
              _InfoItem('Moto', detalle.motoDescripcion),
              _InfoItem('Placa', detalle.motoPlaca),
              _InfoItem('Cliente', detalle.clienteNombre),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoItem {
  const _InfoItem(this.etiqueta, this.valor);
  final String etiqueta;
  final String valor;
}

class _TarjetaInfo extends StatelessWidget {
  const _TarjetaInfo({
    required this.titulo,
    required this.icono,
    required this.items,
  });

  final String titulo;
  final IconData icono;
  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 18, color: const Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 160,
                    child: Text(
                      item.etiqueta,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.valor,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjeTareas extends StatelessWidget {
  const _TarjeTareas({required this.tareas});

  final List<OrdenTarea> tareas;

  @override
  Widget build(BuildContext context) {
    return _TarjetaSeccion(
      titulo: 'Mano de Obra',
      icono: Icons.build_outlined,
      accentColor: const Color(0xFF6366F1),
      child: tareas.isEmpty
          ? const _EstadoVacioSeccion(mensaje: 'Sin tareas registradas')
          : Column(children: tareas.map((t) => _FilaTarea(tarea: t)).toList()),
    );
  }
}

class _FilaTarea extends StatelessWidget {
  const _FilaTarea({required this.tarea});

  final OrdenTarea tarea;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          // Check completado
          Icon(
            tarea.completado
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: tarea.completado
                ? const Color(0xFF10B981)
                : const Color(0xFFD1D5DB),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tarea.servicioNombre,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  tarea.tecnicoNombre,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                if (tarea.notas != null && tarea.notas!.isNotEmpty)
                  Text(
                    tarea.notas!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _fmtMoneda.format(tarea.precioPactado),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

// Tarjeta de repuestos
class _TarjetaRepuestos extends StatelessWidget {
  const _TarjetaRepuestos({required this.repuestos});

  final List<OrdenRepuesto> repuestos;

  @override
  Widget build(BuildContext context) {
    return _TarjetaSeccion(
      titulo: 'Repuestos',
      icono: Icons.settings_outlined,
      accentColor: const Color(0xFFF59E0B),
      child: repuestos.isEmpty
          ? const _EstadoVacioSeccion(mensaje: 'Sin repuestos registrados')
          : Column(
              children: repuestos
                  .map((r) => _FilaRepuesto(repuesto: r))
                  .toList(),
            ),
    );
  }
}

class _FilaRepuesto extends StatelessWidget {
  const _FilaRepuesto({required this.repuesto});

  final OrdenRepuesto repuesto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 16,
            color: Color(0xFFD1D5DB),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              repuesto.productoNombre,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827),
              ),
            ),
          ),
          Text(
            '${repuesto.cantidad % 1 == 0 ? repuesto.cantidad.toInt() : repuesto.cantidad} × ${_fmtMoneda.format(repuesto.precioUnitario)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(width: 12),
          Text(
            _fmtMoneda.format(repuesto.subtotal),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

// Tarjeta de totales
class _TarjetaTotales extends StatelessWidget {
  const _TarjetaTotales({required this.detalle});

  final OrdenDetalle detalle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _FilaTotal('Subtotal mano de obra', detalle.subtotalManoObra, false),
          const SizedBox(height: 8),
          _FilaTotal('Subtotal repuestos', detalle.subtotalRepuestos, false),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
          ),
          _FilaTotal('TOTAL ESTIMADO', detalle.totalEstimado, true),
        ],
      ),
    );
  }
}

class _FilaTotal extends StatelessWidget {
  const _FilaTotal(this.etiqueta, this.valor, this.esTotal);

  final String etiqueta;
  final double valor;
  final bool esTotal;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          etiqueta,
          style: TextStyle(
            fontSize: esTotal ? 15 : 13,
            fontWeight: esTotal ? FontWeight.w700 : FontWeight.w500,
            color: esTotal ? const Color(0xFF111827) : const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(width: 32),
        SizedBox(
          width: 160,
          child: Text(
            _fmtMoneda.format(valor),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: esTotal ? 18 : 14,
              fontWeight: esTotal ? FontWeight.w800 : FontWeight.w500,
              color: esTotal
                  ? const Color(0xFF6366F1)
                  : const Color(0xFF374151),
            ),
          ),
        ),
      ],
    );
  }
}

// Helpers compartidos

class _TarjetaSeccion extends StatelessWidget {
  const _TarjetaSeccion({
    required this.titulo,
    required this.icono,
    required this.accentColor,
    required this.child,
  });

  final String titulo;
  final IconData icono;
  final Color accentColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accentColor, width: 3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EstadoVacioSeccion extends StatelessWidget {
  const _EstadoVacioSeccion({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          mensaje,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF9CA3AF),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
