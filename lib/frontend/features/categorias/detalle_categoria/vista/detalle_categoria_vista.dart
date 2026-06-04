import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/categorias/modelo/categoria.dart';
import '../../../../../backend/features/productos/modelo/producto.dart';
import '../../../../../backend/share/database/locator.dart';
import '../../../../share/temas/colores_app.dart';
import '../../../../share/widgets/dialogos/dialogo_confirmar_eliminar_widget.dart';
import '../../../../share/widgets/input/barra_busqueda_widget.dart';
import '../../../../share/widgets/output/chip_filtro_widget.dart';
import '../../../../share/widgets/output/estado_vacio_widget.dart';
import '../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../../../share/widgets/top_bar_widget.dart';
import '../../../productos/provider/productos_provider.dart';
import '../../../productos/widgets/dialogo_detalle_producto_widget.dart';
import '../../../productos/widgets/dialogo_producto_widget.dart';
import '../../../productos/widgets/tarjeta_producto_widget.dart';
import '../../../proveedores/view_model/proveedores_view_model.dart';
import '../provider/detalle_categoria_provider.dart';

class DetalleCategoriaVista extends ConsumerStatefulWidget {
  const DetalleCategoriaVista({super.key, required this.categoria});

  final Categoria categoria;

  @override
  ConsumerState<DetalleCategoriaVista> createState() =>
      _DetalleCategoriaVistaState();
}

class _DetalleCategoriaVistaState
    extends ConsumerState<DetalleCategoriaVista> {
  late final ProveedoresViewModel _proveedoresVm;
  Timer? _debounce;
  String _busqueda = '';
  FiltroStock _filtroStock = FiltroStock.todos;

  @override
  void initState() {
    super.initState();
    _proveedoresVm = locator<ProveedoresViewModel>();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onBusquedaCambiada(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _busqueda = query.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.bgContent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopBarConBoton(
            titulo: widget.categoria.nombre,
            etiquetaBoton: 'Agregar producto',
            alPresionarBoton: () => DialogoProducto.mostrar(
              context,
              proveedoresVm: _proveedoresVm,
            ),
            mostrarBotonVolver: true,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: BarraBusquedaWidget(
              placeholder: 'Buscar en ${widget.categoria.nombre}...',
              alCambiar: _onBusquedaCambiada,
            ),
          ),
          Expanded(
            child: _CuerpoDetalle(
              categoria: widget.categoria,
              busqueda: _busqueda,
              filtroStock: _filtroStock,
              onFiltroChanged: (f) => setState(() => _filtroStock = f),
              proveedoresVm: _proveedoresVm,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cuerpo ──────────────────────────────────────────────────────────────────
// ConsumerWidget: reacciona al provider de categoría y aplica filtros locales.

class _CuerpoDetalle extends ConsumerWidget {
  const _CuerpoDetalle({
    required this.categoria,
    required this.busqueda,
    required this.filtroStock,
    required this.onFiltroChanged,
    required this.proveedoresVm,
  });

  final Categoria categoria;
  final String busqueda;
  final FiltroStock filtroStock;
  final ValueChanged<FiltroStock> onFiltroChanged;
  final ProveedoresViewModel proveedoresVm;

  static const double _maxAncho  = 250.0;
  static const double _espaciado = 16.0;
  static const double _altura    = 310.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos     = ref.watch(productosDeCategoriaProvider(categoria.id!));
    final filtrados = _aplicarFiltros(todos);
    final hayFiltro =
        busqueda.isNotEmpty || filtroStock != FiltroStock.todos;

    return CustomScrollView(
      slivers: [
        // ── Encabezado + controles ───────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ChipsFiltroStock(
                  filtroActual: filtroStock,
                  onChange: onFiltroChanged,
                ),
                if (filtrados.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ContadorResultados(total: filtrados.length),
                ],
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),

        // ── Grid o estado vacío ──────────────────────────────────
        if (filtrados.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EstadoVacioWidget(
              icono: Icons.inventory_2_outlined,
              textoSinDatos:
                  'Sin productos en "${categoria.nombre}"',
              textoSinResultados:
                  'Ningún producto coincide con la búsqueda.',
              textoCTA:
                  'Presiona "Agregar producto" para crear el primero.',
              hayFiltro: hayFiltro,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: _maxAncho,
                crossAxisSpacing:   _espaciado,
                mainAxisSpacing:    _espaciado,
                mainAxisExtent:     _altura,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final p = filtrados[i];
                  return TarjetaProductoWidget(
                    key: ValueKey(p.id),
                    producto: p,
                    alVerDetalle: () =>
                        DialogoDetalleProductoWidget.mostrar(
                          context,
                          producto: p,
                        ),
                    alEditar: () => DialogoProducto.mostrar(
                      context,
                      productoAEditar: p,
                      proveedoresVm: proveedoresVm,
                    ),
                    alEliminar: () => DialogoConfirmarEliminar.mostrar(
                      context: context,
                      nombreElemento: p.nombre,
                      tipoElemento: 'producto',
                      onConfirmar: () async {
                        final error = await ref
                            .read(productosProvider.notifier)
                            .eliminar(p.id!);
                        if (error != null && context.mounted) {
                          SnackBarMensaje.error(context, error);
                        }
                      },
                    ),
                  );
                },
                childCount: filtrados.length,
              ),
            ),
          ),
      ],
    );
  }

  List<Producto> _aplicarFiltros(List<Producto> todos) {
    var lista = todos;

    if (busqueda.isNotEmpty) {
      final q = busqueda.toLowerCase();
      lista = lista
          .where(
            (p) =>
                p.nombre.toLowerCase().contains(q) ||
                p.sku.toLowerCase().contains(q),
          )
          .toList();
    }

    return switch (filtroStock) {
      FiltroStock.enStock =>
        lista.where((p) => p.estadoStock == EstadoStock.enStock).toList(),
      FiltroStock.stockBajo =>
        lista.where((p) => p.estadoStock == EstadoStock.stockBajo).toList(),
      FiltroStock.sinStock =>
        lista.where((p) => p.estadoStock == EstadoStock.sinStock).toList(),
      FiltroStock.todos => lista,
    };
  }
}

// ── Widgets privados de esta vista ──────────────────────────────────────────

class _ChipsFiltroStock extends StatelessWidget {
  const _ChipsFiltroStock({
    required this.filtroActual,
    required this.onChange,
  });

  final FiltroStock filtroActual;
  final ValueChanged<FiltroStock> onChange;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        ChipFiltro(
          etiqueta: 'Todos',
          seleccionado: filtroActual == FiltroStock.todos,
          alPresionar: () => onChange(FiltroStock.todos),
        ),
        ChipFiltro(
          etiqueta: 'En stock',
          seleccionado: filtroActual == FiltroStock.enStock,
          alPresionar: () => onChange(FiltroStock.enStock),
          color: ColoresApp.statusPaid,
        ),
        ChipFiltro(
          etiqueta: 'Stock bajo',
          seleccionado: filtroActual == FiltroStock.stockBajo,
          alPresionar: () => onChange(FiltroStock.stockBajo),
          color: ColoresApp.statusPending,
        ),
        ChipFiltro(
          etiqueta: 'Sin stock',
          seleccionado: filtroActual == FiltroStock.sinStock,
          alPresionar: () => onChange(FiltroStock.sinStock),
          color: ColoresApp.statusDebt,
        ),
      ],
    );
  }
}

class _ContadorResultados extends StatelessWidget {
  const _ContadorResultados({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$total PRODUCTO${total == 1 ? '' : 'S'}',
      style: const TextStyle(
        color: ColoresApp.textLight,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
      ),
    );
  }
}
