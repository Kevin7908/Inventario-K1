import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../../../../backend/features/ventas/facturas/modelo/factura_resumen.dart';
import '../../../../share/widgets/botones/dialogo_confirmar_eliminar_widget.dart';
import '../../../../share/widgets/input/barra_busqueda_widget.dart';
import '../../../../share/widgets/output/estado_error_widget.dart';
import '../../../../share/widgets/output/estado_vacio_widget.dart';
import '../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../../../share/widgets/top_bar_widget.dart';
import '../detalle_factura/factura_detalle_page.dart';
import '../provider/facturas_provider.dart';
import '../widgets/factura_fila_widget.dart';
import '../widgets/facturas_resumen_cartas_widget.dart';

class FacturasVista extends ConsumerStatefulWidget {
  const FacturasVista({super.key});

  @override
  ConsumerState<FacturasVista> createState() => _FacturasVistaState();
}

class _FacturasVistaState extends ConsumerState<FacturasVista> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TopBarWidget(titulo: 'Facturación'),
          const Expanded(child: _CuerpoFacturas()),
        ],
      ),
    );
  }
}

class _CuerpoFacturas extends ConsumerStatefulWidget {
  const _CuerpoFacturas();

  @override
  ConsumerState<_CuerpoFacturas> createState() => _CuerpoFacturasState();
}

class _CuerpoFacturasState extends ConsumerState<_CuerpoFacturas> {
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
        final lista = ref.watch(facturasServicioFiltradas);
        final metricas = FacturasMetricas.deFacturas(
          estado.facturas.where((f) => f.tipo == TipoVenta.servicio).toList(),
        );

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FacturasResumenCartas(metricas: metricas),
              const SizedBox(height: 24),
              _BarraFiltros(
                controller: _searchController,
                filtroActual: filtroActual,
                onBuscar: _onBuscar,
                onFiltroEstado: (e) =>
                    ref.read(facturasProvider.notifier).filtrarEstadoPago(e),
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
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const FacturaTablaEncabezado(),
                      Expanded(
                        child: lista.isEmpty
                            ? const EstadoVacioWidget(
                                icono: Icons.receipt_long_outlined,
                                textoSinDatos: 'Sin facturas',
                                textoSinResultados:
                                    'Crea una nueva factura con el botón superior.',
                                textoCTA: '',
                              )
                            : _ListaFacturas(
                                facturas: lista,
                                onTap: (f) => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        FacturaDetallePage(facturaId: f.id),
                                  ),
                                ),
                                onEliminar: (f) =>
                                    _confirmarEliminarDesde(context, ref, f),
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

  void _confirmarEliminarDesde(
      BuildContext context, WidgetRef ref, FacturaResumen factura) {
    DialogoConfirmarEliminar.mostrar(
      context: context,
      nombreElemento: factura.numeroFactura,
      tipoElemento: 'factura',
      onConfirmar: () async {
        final error =
            await ref.read(facturasProvider.notifier).eliminar(factura.id);
        if (!context.mounted) return;
        if (error != null) {
          SnackBarMensaje.error(context, error);
        } else {
          SnackBarMensaje.success(context, 'Factura eliminada.');
        }
      },
    );
  }
}

class _BarraFiltros extends StatelessWidget {
  const _BarraFiltros({
    required this.controller,
    required this.filtroActual,
    required this.onBuscar,
    required this.onFiltroEstado,
  });

  final TextEditingController controller;
  final EstadoPago? filtroActual;
  final ValueChanged<String> onBuscar;
  final ValueChanged<EstadoPago?> onFiltroEstado;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BarraBusquedaWidget(
            placeholder: 'Buscar por factura, cliente...',
            alCambiar: onBuscar,
          ),
        ),
        const SizedBox(width: 12),
        _Chip(
          label: 'Todas',
          seleccionado: filtroActual == null,
          color: const Color(0xFF374151),
          onTap: () => onFiltroEstado(null),
        ),
        const SizedBox(width: 6),
        _Chip(
          label: 'Pendientes',
          seleccionado: filtroActual == EstadoPago.pendiente,
          color: const Color(0xFFF59E0B),
          onTap: () => onFiltroEstado(
            filtroActual == EstadoPago.pendiente ? null : EstadoPago.pendiente,
          ),
        ),
        const SizedBox(width: 6),
        _Chip(
          label: 'Pagadas',
          seleccionado: filtroActual == EstadoPago.pagado,
          color: const Color(0xFF10B981),
          onTap: () => onFiltroEstado(
            filtroActual == EstadoPago.pagado ? null : EstadoPago.pagado,
          ),
        ),
        const SizedBox(width: 6),
        _Chip(
          label: 'Anuladas',
          seleccionado: filtroActual == EstadoPago.anulada,
          color: const Color(0xFFEF4444),
          onTap: () => onFiltroEstado(
            filtroActual == EstadoPago.anulada ? null : EstadoPago.anulada,
          ),
        ),
      ],
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
            color: seleccionado ? color : const Color(0xFFE5E7EB),
          ),
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

class _ListaFacturas extends StatelessWidget {
  const _ListaFacturas({
    required this.facturas,
    required this.onTap,
    required this.onEliminar,
  });

  final List<FacturaResumen> facturas;
  final ValueChanged<FacturaResumen> onTap;
  final ValueChanged<FacturaResumen> onEliminar;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: facturas.length,
      addAutomaticKeepAlives: false,
      itemBuilder: (_, i) {
        final f = facturas[i];
        return FacturaFilaWidget(
          key: ValueKey(f.id),
          factura: f,
          onTap: () => onTap(f),
          onEliminar: () => onEliminar(f),
        );
      },
    );
  }
}
