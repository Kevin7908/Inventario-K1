import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../backend/share/database/locator.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/botones/dialogo_confirmar_eliminar_widget.dart';
import '../../../share/widgets/input/barra_busqueda_widget.dart';
import '../../../share/widgets/output/chip_filtro_widget.dart';
import '../../../share/widgets/output/estado_error_widget.dart';
import '../../../share/widgets/output/estado_vacio_widget.dart';
import '../../../share/widgets/top_bar_widget.dart';
import '../../categorias/view_model/categorias_view_model.dart';
import '../../proveedores/view_model/proveedores_view_model.dart';
import '../../unidades_medida/view_model/unidad_medida_view_model.dart';
import '../view_model/productos_view_model.dart';
import '../widgets/dialogo_detalle_producto_widget.dart';
import '../widgets/dialogo_producto_widget.dart';
import '../widgets/tarjeta_producto_widget.dart';

class ProductosVista extends StatefulWidget {
  const ProductosVista({super.key});

  @override
  State<ProductosVista> createState() => _ProductosVistaState();
}

class _ProductosVistaState extends State<ProductosVista> {
  // ViewModels resueltos UNA SOLA VEZ en initState — no en build()
  late final ProductosViewModel _vm;
  late final CategoriasViewModel _categoriasVm;
  late final ProveedoresViewModel _proveedoresVm;
  late final UnidadesMedidaViewModel _unidadesVm;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _vm = locator<ProductosViewModel>();
    _categoriasVm = locator<CategoriasViewModel>();
    _proveedoresVm = locator<ProveedoresViewModel>();
    _unidadesVm = locator<UnidadesMedidaViewModel>();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _vm.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _vm.buscar(query);
    });
  }

  void _abrirDialogoAgregar() {
    DialogoProducto.mostrar(
      context,
      viewModel: _vm,
      categoriasVm: _categoriasVm,
      proveedoresVm: _proveedoresVm,
      unidadesVm: _unidadesVm,
    );
  }

  @override
  Widget build(BuildContext context) {
    // OPTIMIZACIÓN: MultiProvider declarado aquí pero SIN depender de
    // ningún estado volátil. Los .value providers inyectan instancias
    // ya creadas en initState → no se recrea el árbol en cada rebuild.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ProductosViewModel>.value(value: _vm),
        ChangeNotifierProvider<CategoriasViewModel>.value(value: _categoriasVm),
        ChangeNotifierProvider<ProveedoresViewModel>.value(value: _proveedoresVm),
        ChangeNotifierProvider<UnidadesMedidaViewModel>.value(value: _unidadesVm),
      ],
      child: Scaffold(
        backgroundColor: ColoresApp.bgContent,
        body: Column(
          children: [
            // TopBar estático — no necesita Consumer:
            // el botón "Agregar" siempre está habilitado.
            TopBarConBoton(
              titulo: 'Productos',
              etiquetaBoton: 'Agregar',
              alPresionarBoton: _abrirDialogoAgregar,
            ),

            // Barra de búsqueda FUERA de cualquier Consumer.
            // Solo llama al VM via callback — no se reconstruye con él.
            BarraBusquedaWidget(
              placeholder: 'Buscar producto, referencia, SKU...',
              alCambiar: _onSearchChanged,
            ),

            // Cuerpo: el único Consumer confinado a lo que realmente varía.
            const Expanded(child: _CuerpoProductos()),
          ],
        ),
      ),
    );
  }
}

class _CuerpoProductos extends StatelessWidget {
  const _CuerpoProductos();

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductosViewModel>(
      builder: (context, vm, _) {
        if (vm.estaCargando) {
          return const Center(
            child: CircularProgressIndicator(color: ColoresApp.primary),
          );
        }

        if (vm.estado == EstadoProductos.error) {
          return EstadoErrorWidget(
            mensaje: vm.mensajeError ?? 'Error desconocido',
            alReintentar: vm.limpiarError,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chips de filtro
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: _ChipsFiltroStock(vm: vm),
            ),

            const SizedBox(height: 12),

            // Contador — solo cuando hay resultados
            if (vm.productos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: _ContadorProductos(total: vm.productos.length),
              ),

            const SizedBox(height: 4),

            // Contenido: vacío o 
            Expanded(
              child: vm.productos.isEmpty
                  ? EstadoVacioWidget(
                      icono: Icons.inventory_2_outlined,
                      textoSinDatos: 'Sin productos aún',
                      textoSinResultados: 'No hay productos que coincidan.',
                      textoCTA:
                          'Crea tu primer producto presionando "Agregar".',
                      hayFiltro: vm.consultaBusqueda.isNotEmpty ||
                          vm.filtroStock != FiltroStock.todos,
                    )
                  : CustomScrollView(
                      slivers: [
                        _SliverGrillaProductos(vm: vm),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ChipsFiltroStock extends StatelessWidget {
  const _ChipsFiltroStock({required this.vm});
  final ProductosViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ChipFiltro(
          etiqueta: 'Todos',
          seleccionado: vm.filtroStock == FiltroStock.todos,
          alPresionar: () => vm.filtrarPorStock(FiltroStock.todos),
        ),
        ChipFiltro(
          etiqueta: 'En stock',
          seleccionado: vm.filtroStock == FiltroStock.enStock,
          alPresionar: () => vm.filtrarPorStock(FiltroStock.enStock),
          color: const Color(0xFF10B981),
        ),
        ChipFiltro(
          etiqueta: 'Stock bajo',
          seleccionado: vm.filtroStock == FiltroStock.stockBajo,
          alPresionar: () => vm.filtrarPorStock(FiltroStock.stockBajo),
          color: const Color(0xFFF59E0B),
        ),
        ChipFiltro(
          etiqueta: 'Sin stock',
          seleccionado: vm.filtroStock == FiltroStock.sinStock,
          alPresionar: () => vm.filtrarPorStock(FiltroStock.sinStock),
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

class _SliverGrillaProductos extends StatelessWidget {
  const _SliverGrillaProductos({required this.vm});
  final ProductosViewModel vm;

  static const double _maxAnchoCelda = 250.0;
  static const double _espaciado = 16.0;

  static const double _alturaCelda = 310.0;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final producto = vm.productos[i];
            return TarjetaProductoWidget(
              key: ValueKey(producto.id),
              producto: producto,
              alVerDetalle: () => DialogoDetalleProductoWidget.mostrar(
                context,
                producto: producto,
              ),
              alEditar: () => DialogoProducto.mostrar(
                context,
                productoAEditar: producto,
                viewModel: vm,
                categoriasVm: context.read<CategoriasViewModel>(),
                proveedoresVm: context.read<ProveedoresViewModel>(),
                unidadesVm: context.read<UnidadesMedidaViewModel>(),
              ),
              alEliminar: () => DialogoConfirmarEliminar.mostrar(
                context: context,
                nombreElemento: producto.nombre,
                tipoElemento: 'producto',
                onConfirmar: () => vm.eliminarProducto(producto.id!),
              ),
            );
          },
          childCount: vm.productos.length,
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: _maxAnchoCelda,
          crossAxisSpacing: _espaciado,
          mainAxisSpacing: _espaciado,
          mainAxisExtent: _alturaCelda, // ← garantiza lazy loading O(1)
        ),
      ),
    );
  }
}