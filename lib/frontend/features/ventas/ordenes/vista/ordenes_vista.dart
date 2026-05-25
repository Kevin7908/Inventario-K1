import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/ventas/ordenes/enum/enum_ordenes.dart';
import '../../../../../backend/features/ventas/ordenes/modelo/orden_resumen.dart';
import '../../../../share/widgets/botones/dialogo_confirmar_eliminar_widget.dart';
import '../../../../share/widgets/input/barra_busqueda_widget.dart';
import '../../../../share/widgets/output/estado_error_widget.dart';
import '../../../../share/widgets/output/estado_vacio_widget.dart';
import '../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../../../share/widgets/top_bar_widget.dart';
import '../provider/ordenes_provider.dart';
import '../widgets/dialogo_crear_editar_orden.dart';
import '../widgets/orden_fila_widget.dart';
import '../widgets/ordenes_resumen_carta_widget.dart';
import '../detalle_orden/orden_detalle_page.dart';

class OrdenesVista extends ConsumerWidget {
  const OrdenesVista({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TopBarConBoton(
            titulo: 'Órdenes de Servicio',
            etiquetaBoton: 'Agregar',
            alPresionarBoton: () => _abrirNuevaOrden(context, ref),
          ),
          const Expanded(child: _CuerpoOrdenes()),
        ],
      ),
    );
  }

  void _abrirNuevaOrden(BuildContext context, WidgetRef ref) {
    DialogoCrearEditarOrden.mostrar(context);
  }
}

class _CuerpoOrdenes extends ConsumerStatefulWidget {
  const _CuerpoOrdenes();

  @override
  ConsumerState<_CuerpoOrdenes> createState() => _CuerpoOrdenesState();
}

class _CuerpoOrdenesState extends ConsumerState<_CuerpoOrdenes> {
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
      ref.read(ordenesProvider.notifier).buscar(valor);
    });
  }

  void _onFiltroEstado(EstadoOrden? estado) {
    ref.read(ordenesProvider.notifier).filtrarEstado(estado);
  }

  void _irADetalle(OrdenResumen orden) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrdenDetalleVista(ordenId: orden.id)),
    );
  }

  Future<void> _editarOrden(OrdenResumen orden) async {
    final detalle = await ref.read(ordenDetalleProvider(orden.id).future);
    if (!mounted) return;
    await DialogoCrearEditarOrden.mostrar(context, ordenAEditar: detalle);
  }

  void _confirmarEliminar(OrdenResumen orden) {
    DialogoConfirmarEliminar.mostrar(
      context: context,
      nombreElemento: orden.numeroOrden,
      tipoElemento: 'orden',
      onConfirmar: () async {
        final error = await ref
            .read(ordenesProvider.notifier)
            .eliminar(orden.id);
        if (!mounted) return;
        if (error != null) {
          SnackBarMensaje.error(context, error);
        } else {
          SnackBarMensaje.success(context, 'Orden eliminada');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final estadoAsync = ref.watch(ordenesProvider);
    final filtroEstadoActual = estadoAsync.value?.filtroEstado;

    return estadoAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EstadoErrorWidget(
        mensaje: e.toString(),
        alReintentar: () => ref.invalidate(ordenesProvider),
      ),
      data: (estado) {
        final lista = ref.watch(ordenesFiltradas);
        final metricas = OrdenesMetricas.deOrdenes(estado.ordenes);

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OrdenesResumenCards(metricas: metricas),
              const SizedBox(height: 24),
              _BarraFiltros(
                controller: _searchController,
                filtroActual: filtroEstadoActual,
                onBuscar: _onBuscar,
                onFiltroEstado: _onFiltroEstado,
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
                      const OrdenTablaEncabezado(),
                      Expanded(
                        child: lista.isEmpty
                            ? const EstadoVacioWidget(
                                icono: Icons.info_outline,
                                textoSinDatos: 'No hay órdenes',
                                textoSinResultados:
                                    'Crea una nueva orden con el botón superior.',
                                textoCTA: '',
                              )
                            : _ListaOrdenes(
                                ordenes: lista,
                                onTap: _irADetalle,
                                onEditar: _editarOrden,
                                onEliminar: _confirmarEliminar,
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
}

class _BarraFiltros extends StatelessWidget {
  const _BarraFiltros({
    required this.controller,
    required this.filtroActual,
    required this.onBuscar,
    required this.onFiltroEstado,
  });

  final TextEditingController controller;
  final EstadoOrden? filtroActual;
  final ValueChanged<String> onBuscar;
  final ValueChanged<EstadoOrden?> onFiltroEstado;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BarraBusquedaWidget(
            placeholder: 'Buscar por moto, cliente, #orden...',
            alCambiar: onBuscar,
          ),
        ),
        const SizedBox(width: 12),
        _ChipEstado(
          label: 'Todas',
          estado: null,
          seleccionado: filtroActual == null,
          onTap: () => onFiltroEstado(null),
        ),
        const SizedBox(width: 6),
        _ChipEstado(
          label: 'Abiertas',
          estado: EstadoOrden.abierta,
          seleccionado: filtroActual == EstadoOrden.abierta,
          onTap: () => onFiltroEstado(
            filtroActual == EstadoOrden.abierta ? null : EstadoOrden.abierta,
          ),
        ),
        const SizedBox(width: 6),
        _ChipEstado(
          label: 'Listas',
          estado: EstadoOrden.lista,
          seleccionado: filtroActual == EstadoOrden.lista,
          onTap: () => onFiltroEstado(
            filtroActual == EstadoOrden.lista ? null : EstadoOrden.lista,
          ),
        ),
        const SizedBox(width: 6),
        _ChipEstado(
          label: 'Entregadas',
          estado: EstadoOrden.entregada,
          seleccionado: filtroActual == EstadoOrden.entregada,
          onTap: () => onFiltroEstado(
            filtroActual == EstadoOrden.entregada
                ? null
                : EstadoOrden.entregada,
          ),
        ),
      ],
    );
  }
}

class _ChipEstado extends StatelessWidget {
  const _ChipEstado({
    required this.label,
    required this.estado,
    required this.seleccionado,
    required this.onTap,
  });

  final String label;
  final EstadoOrden? estado;
  final bool seleccionado;
  final VoidCallback onTap;

  Color get _color => switch (estado) {
    EstadoOrden.abierta => const Color(0xFF6366F1),
    EstadoOrden.lista => const Color(0xFF10B981),
    EstadoOrden.entregada => const Color(0xFF6B7280),
    EstadoOrden.anulada => const Color(0xFFEF4444),
    null => const Color(0xFF374151),
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: seleccionado ? _color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: seleccionado ? _color : const Color(0xFFE5E7EB),
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

class _ListaOrdenes extends StatelessWidget {
  const _ListaOrdenes({
    required this.ordenes,
    required this.onTap,
    required this.onEditar,
    required this.onEliminar,
  });

  final List<OrdenResumen> ordenes;
  final ValueChanged<OrdenResumen> onTap;
  final ValueChanged<OrdenResumen> onEditar;
  final ValueChanged<OrdenResumen> onEliminar;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: ordenes.length,
      addAutomaticKeepAlives: false,
      itemBuilder: (_, i) {
        final orden = ordenes[i];
        return OrdenFilaWidget(
          key: ValueKey(orden.id),
          orden: orden,
          onTap: () => onTap(orden),
          onEditar: () => onEditar(orden),
          onEliminar: () => onEliminar(orden),
        );
      },
    );
  }
}
