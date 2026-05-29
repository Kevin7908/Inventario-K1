import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/share/database/locator.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/dialogos/dialogo_confirmar_eliminar_widget.dart';
import '../../../share/widgets/input/barra_busqueda_widget.dart';
import '../../../share/widgets/output/chip_filtro_widget.dart';
import '../../../share/widgets/output/estado_error_widget.dart';
import '../../../share/widgets/output/estado_vacio_widget.dart';
import '../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../../share/widgets/top_bar_widget.dart';
import '../../categorias/view_model/categorias_view_model.dart';
import '../../proveedores/view_model/proveedores_view_model.dart';
import '../../unidades_medida/view_model/unidad_medida_view_model.dart';
import '../provider/productos_provider.dart';
import '../widgets/dialogo_detalle_producto_widget.dart';
import '../widgets/dialogo_producto_widget.dart';
import '../widgets/tarjeta_producto_widget.dart';

class ProductosVista extends ConsumerStatefulWidget {
  const ProductosVista({super.key});

  @override
  ConsumerState<ProductosVista> createState() => _ProductosVistaState();
}

class _ProductosVistaState extends ConsumerState<ProductosVista> {
  // Los módulos de categorías/proveedores/unidades aún usan GetIt.
  // Solo se leen una vez en initState — no se recrean en build.
  late final CategoriasViewModel _categoriasVm;
  late final ProveedoresViewModel _proveedoresVm;
  late final UnidadesMedidaViewModel _unidadesVm;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _categoriasVm = locator<CategoriasViewModel>();
    _proveedoresVm = locator<ProveedoresViewModel>();
    _unidadesVm   = locator<UnidadesMedidaViewModel>();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(productosProvider.notifier).buscar(query);
    });
  }

  void _abrirDialogoAgregar() {
    DialogoProducto.mostrar(
      context,
      categoriasVm: _categoriasVm,
      proveedoresVm: _proveedoresVm,
      unidadesVm:   _unidadesVm,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.bgContent,
      body: Column(
        children: [
          TopBarConBoton(
            titulo: 'Productos',
            etiquetaBoton: 'Agregar',
            alPresionarBoton: _abrirDialogoAgregar,
          ),
          BarraBusquedaWidget(
            placeholder: 'Buscar producto, referencia, SKU...',
            alCambiar: _onSearchChanged,
          ),
          Expanded(
            child: _CuerpoProductos(
              categoriasVm: _categoriasVm,
              proveedoresVm: _proveedoresVm,
              unidadesVm:   _unidadesVm,
            ),
          ),
        ],
      ),
    );
  }
}

// Cuerpo — maneja los estados async del provider

class _CuerpoProductos extends ConsumerWidget {
  const _CuerpoProductos({
    required this.categoriasVm,
    required this.proveedoresVm,
    required this.unidadesVm,
  });

  final CategoriasViewModel categoriasVm;
  final ProveedoresViewModel proveedoresVm;
  final UnidadesMedidaViewModel unidadesVm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estadoAsync = ref.watch(productosProvider);

    return estadoAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: ColoresApp.primary)),
      error: (e, _) => EstadoErrorWidget(
        mensaje: e.toString(),
        alReintentar: () => ref.invalidate(productosProvider),
      ),
      data: (estado) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: _ChipsFiltroStock(
              filtroActual: estado.filtroStock,
              onChange: (f) =>
                  ref.read(productosProvider.notifier).filtrarPorStock(f),
            ),
          ),
          const SizedBox(height: 12),
          if (estado.filtrados.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: _ContadorProductos(total: estado.filtrados.length),
            ),
          const SizedBox(height: 4),
          Expanded(
            child: estado.filtrados.isEmpty
                ? EstadoVacioWidget(
                    icono: Icons.inventory_2_outlined,
                    textoSinDatos: 'Sin productos aún',
                    textoSinResultados: 'No hay productos que coincidan.',
                    textoCTA:
                        'Crea tu primer producto presionando "Agregar".',
                    hayFiltro: estado.busqueda.isNotEmpty ||
                        estado.filtroStock != FiltroStock.todos,
                  )
                : CustomScrollView(
                    slivers: [
                      _SliverGrillaProductos(
                        categoriasVm: categoriasVm,
                        proveedoresVm: proveedoresVm,
                        unidadesVm:   unidadesVm,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// Chips de filtro — StatelessWidget puro, recibe datos por props

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
          color: const Color(0xFF10B981),
        ),
        ChipFiltro(
          etiqueta: 'Stock bajo',
          seleccionado: filtroActual == FiltroStock.stockBajo,
          alPresionar: () => onChange(FiltroStock.stockBajo),
          color: const Color(0xFFF59E0B),
        ),
        ChipFiltro(
          etiqueta: 'Sin stock',
          seleccionado: filtroActual == FiltroStock.sinStock,
          alPresionar: () => onChange(FiltroStock.sinStock),
          color: const Color(0xFFEF4444),
        ),
      ],
    );
  }
}

class _ContadorProductos extends StatelessWidget {
  const _ContadorProductos({required this.total});
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

// Grid de productos — ConsumerWidget que lee productosFiltradosProvider
// Solo se reconstruye cuando la lista filtrada cambia, no el estado completo.

class _SliverGrillaProductos extends ConsumerWidget {
  const _SliverGrillaProductos({
    required this.categoriasVm,
    required this.proveedoresVm,
    required this.unidadesVm,
  });

  final CategoriasViewModel categoriasVm;
  final ProveedoresViewModel proveedoresVm;
  final UnidadesMedidaViewModel unidadesVm;

  static const double _maxAncho  = 250.0;
  static const double _espaciado = 16.0;
  static const double _altura    = 310.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productos = ref.watch(productosFiltradosProvider);

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: _maxAncho,
          crossAxisSpacing:   _espaciado,
          mainAxisSpacing:    _espaciado,
          mainAxisExtent:     _altura,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final producto = productos[i];
            return TarjetaProductoWidget(
              key: ValueKey(producto.id),
              producto: producto,
              alVerDetalle: () =>
                  DialogoDetalleProductoWidget.mostrar(context, producto: producto),
              alEditar: () => DialogoProducto.mostrar(
                context,
                productoAEditar: producto,
                categoriasVm:    categoriasVm,
                proveedoresVm:   proveedoresVm,
                unidadesVm:      unidadesVm,
              ),
              alEliminar: () => DialogoConfirmarEliminar.mostrar(
                context: context,
                nombreElemento: producto.nombre,
                tipoElemento:   'producto',
                onConfirmar: () async {
                  final error = await ref
                      .read(productosProvider.notifier)
                      .eliminar(producto.id!);
                  if (error != null && context.mounted) {
                    SnackBarMensaje.error(context, error);
                  }
                },
              ),
            );
          },
          childCount: productos.length,
        ),
      ),
    );
  }
}
