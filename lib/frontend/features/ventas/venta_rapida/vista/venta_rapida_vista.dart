import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../../../../backend/features/ventas/facturas/modelo/factura_resumen.dart';
import '../../../../share/formateadores/moneda_formateador.dart';
import '../../../../share/temas/colores_app.dart';
import '../../../../share/widgets/botones/dialogo_confirmar_eliminar_widget.dart';
import '../../../../share/widgets/input/barra_busqueda_widget.dart';
import '../../../../share/widgets/output/estado_error_widget.dart';
import '../../../../share/widgets/output/estado_vacio_widget.dart';
import '../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../../../share/widgets/top_bar_widget.dart';
import '../../facturas/detalle_factura/factura_detalle_page.dart';
import '../../facturas/provider/facturas_provider.dart';
import '../../facturas/widgets/dialogo_crear_factura.dart';
import '../../facturas/widgets/factura_fila_widget.dart';

class VentaRapidaVista extends ConsumerStatefulWidget {
  const VentaRapidaVista({super.key});

  @override
  ConsumerState<VentaRapidaVista> createState() => _VentaRapidaVistaState();
}

class _VentaRapidaVistaState extends ConsumerState<VentaRapidaVista> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TopBarConBoton(
            titulo: 'Venta Rápida (Mostrador)',
            etiquetaBoton: 'Nueva venta',
            alPresionarBoton: () => DialogoCrearFactura.mostrar(context, tipoFijo: TipoVenta.mostrador),
          ),
          const Expanded(child: _CuerpoVentaRapida()),
        ],
      ),
    );
  }
}

class _CuerpoVentaRapida extends ConsumerStatefulWidget {
  const _CuerpoVentaRapida();

  @override
  ConsumerState<_CuerpoVentaRapida> createState() => _CuerpoVentaRapidaState();
}

class _CuerpoVentaRapidaState extends ConsumerState<_CuerpoVentaRapida> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onBuscar(String valor) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      ref.read(facturasProvider.notifier).buscar(valor);
    });
  }

  @override
  Widget build(BuildContext context) {
    final estadoAsync = ref.watch(facturasProvider);
    final filtroActual = estadoAsync.value?.filtroEstadoPago;

    return estadoAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EstadoErrorWidget(
        mensaje: e.toString(),
        alReintentar: () => ref.invalidate(facturasProvider),
      ),
      data: (estado) {
        final lista = ref.watch(facturasRapidaFiltradas);
        final metricas = _calcularMetricas(
          estado.facturas.where((f) => f.tipo == TipoVenta.mostrador).toList(),
        );

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CardsMetricas(metricas: metricas),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: BarraBusquedaWidget(
                      placeholder: 'Buscar por número de venta...',
                      alCambiar: _onBuscar,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _Chip(
                    label: 'Todas',
                    seleccionado: filtroActual == null,
                    color: const Color(0xFF374151),
                    onTap: () =>
                        ref.read(facturasProvider.notifier).filtrarEstadoPago(null),
                  ),
                  const SizedBox(width: 6),
                  _Chip(
                    label: 'Pendientes',
                    seleccionado: filtroActual == EstadoPago.pendiente,
                    color: const Color(0xFFF59E0B),
                    onTap: () => ref.read(facturasProvider.notifier).filtrarEstadoPago(
                          filtroActual == EstadoPago.pendiente
                              ? null
                              : EstadoPago.pendiente,
                        ),
                  ),
                  const SizedBox(width: 6),
                  _Chip(
                    label: 'Pagadas',
                    seleccionado: filtroActual == EstadoPago.pagado,
                    color: const Color(0xFF10B981),
                    onTap: () => ref.read(facturasProvider.notifier).filtrarEstadoPago(
                          filtroActual == EstadoPago.pagado
                              ? null
                              : EstadoPago.pagado,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 8,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    children: [
                      const FacturaTablaEncabezado(),
                      Expanded(
                        child: lista.isEmpty
                            ? const EstadoVacioWidget(
                                icono: Icons.point_of_sale_outlined,
                                textoSinDatos: 'Sin ventas rápidas',
                                textoSinResultados:
                                    'Crea una nueva venta con el botón superior.',
                                textoCTA: '',
                              )
                            : ListView.builder(
                                itemCount: lista.length,
                                addAutomaticKeepAlives: false,
                                itemBuilder: (_, i) {
                                  final f = lista[i];
                                  return FacturaFilaWidget(
                                    key: ValueKey(f.id),
                                    factura: f,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            FacturaDetallePage(facturaId: f.id),
                                      ),
                                    ),
                                    onEliminar: () =>
                                        _confirmarEliminar(context, ref, f),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmarEliminar(
      BuildContext context, WidgetRef ref, FacturaResumen f) {
    DialogoConfirmarEliminar.mostrar(
      context: context,
      nombreElemento: f.numeroFactura,
      tipoElemento: 'venta',
      onConfirmar: () async {
        final error =
            await ref.read(facturasProvider.notifier).eliminar(f.id);
        if (!context.mounted) return;
        if (error != null) {
          SnackBarMensaje.error(context, error);
        } else {
          SnackBarMensaje.success(context, 'Venta eliminada.');
        }
      },
    );
  }

  _Metricas _calcularMetricas(List<FacturaResumen> lista) {
    final ahora = DateTime.now();
    double cobrado = 0;
    int numMes = 0;
    double pendiente = 0;

    for (final f in lista) {
      if (f.estadoPago == EstadoPago.pagado &&
          f.creadoEn != null &&
          f.creadoEn!.month == ahora.month &&
          f.creadoEn!.year == ahora.year) {
        cobrado += f.total;
        numMes++;
      }
      if (f.estadoPago == EstadoPago.pendiente) pendiente += f.total;
    }
    return _Metricas(
        cobradoMes: cobrado, numMes: numMes, pendiente: pendiente, total: lista.length);
  }
}

class _Metricas {
  const _Metricas(
      {required this.cobradoMes,
      required this.numMes,
      required this.pendiente,
      required this.total});
  final double cobradoMes;
  final int numMes;
  final double pendiente;
  final int total;
}

class _CardsMetricas extends StatelessWidget {
  const _CardsMetricas({required this.metricas});
  final _Metricas metricas;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            titulo: 'Cobrado este mes',
            valor: fmtMoneda(metricas.cobradoMes),
            subtitulo: '${metricas.numMes} ventas',
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            titulo: 'Pendiente de cobro',
            valor: fmtMoneda(metricas.pendiente),
            subtitulo: 'Por cobrar',
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            titulo: 'Total ventas',
            valor: metricas.total.toString(),
            subtitulo: 'Todas las ventas',
            color: ColoresApp.accentTeal,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.titulo,
    required this.valor,
    required this.subtitulo,
    required this.color,
  });

  final String titulo;
  final String valor;
  final String subtitulo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(valor,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1)),
          const SizedBox(height: 4),
          Text(subtitulo,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.seleccionado,
    required this.color,
    required this.onTap,
  });
  final String label;
  final bool seleccionado;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: seleccionado ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: seleccionado ? color : const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: seleccionado ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}
