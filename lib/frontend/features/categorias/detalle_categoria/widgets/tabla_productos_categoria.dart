import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/productos/modelo/producto.dart';
import '../../../../share/share.dart';
import '../../../productos/provider/productos_provider.dart';
import '../../../productos/widgets/columnas_tabla_producto.dart';
import '../provider/detalle_categoria_provider.dart';

/// Chips de estado de stock, con los colores del semáforo del diseño.
class ChipsFiltroStock extends StatelessWidget {
  const ChipsFiltroStock({
    super.key,
    required this.filtroActual,
    required this.alCambiar,
  });

  final FiltroStock filtroActual;
  final ValueChanged<FiltroStock> alCambiar;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        ChipFiltro(
          etiqueta: 'Todos',
          icono: Icons.grid_view_rounded,
          seleccionado: filtroActual == FiltroStock.todos,
          alPresionar: () => alCambiar(FiltroStock.todos),
        ),
        ChipFiltro(
          etiqueta: 'En stock',
          seleccionado: filtroActual == FiltroStock.enStock,
          alPresionar: () => alCambiar(FiltroStock.enStock),
          colorActivo: ColoresApp.stockOk,
        ),
        ChipFiltro(
          etiqueta: 'Stock bajo',
          seleccionado: filtroActual == FiltroStock.stockBajo,
          alPresionar: () => alCambiar(FiltroStock.stockBajo),
          colorActivo: ColoresApp.stockLow,
        ),
        ChipFiltro(
          etiqueta: 'Agotados',
          seleccionado: filtroActual == FiltroStock.sinStock,
          alPresionar: () => alCambiar(FiltroStock.sinStock),
          colorActivo: ColoresApp.stockOut,
        ),
      ],
    );
  }
}

/// Tabla paginada de los productos de una categoría.
///
/// Usa [columnasTablaProducto], las mismas columnas del catálogo de Productos,
/// para que la lectura sea idéntica en las dos pantallas. Omite la columna de
/// categoría porque aquí todas las filas son de la misma.
class TablaProductosCategoria extends ConsumerWidget {
  const TablaProductosCategoria({
    super.key,
    required this.categoriaId,
    required this.nombreCategoria,
    required this.busqueda,
    required this.filtroStock,
    required this.pagina,
    required this.alCambiarPagina,
    required this.alVerProducto,
  });

  final int categoriaId;
  final String nombreCategoria;
  final String busqueda;
  final FiltroStock filtroStock;
  final int pagina;
  final ValueChanged<int> alCambiarPagina;
  final ValueChanged<Producto> alVerProducto;

  static const int _tamanoPagina = 25;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPagina = ref.watch(
      productosDeCategoriaProvider((
        categoriaId: categoriaId,
        busqueda: busqueda,
        stock: filtroStock,
        pagina: pagina,
        tamano: _tamanoPagina,
      )),
    );

    if (asyncPagina.isLoading && !asyncPagina.hasValue) {
      return const Center(
        child: CircularProgressIndicator(color: ColoresApp.goGreen),
      );
    }
    if (asyncPagina.hasError && !asyncPagina.hasValue) {
      return Center(
        child: Text(
          'Error al cargar los productos: ${asyncPagina.error}',
          style: TipografiaApp.cuerpo,
        ),
      );
    }

    final resultado = asyncPagina.requireValue;
    final hayFiltro = busqueda.isNotEmpty || filtroStock != FiltroStock.todos;
    final totalPaginas = resultado.total <= 0
        ? 1
        : (resultado.total + _tamanoPagina - 1) ~/ _tamanoPagina;

    return Column(
      children: [
        Expanded(
          child: TablaGenerica<Producto>(
            items: resultado.items,
            alPresionarFila: alVerProducto,
            mensajeVacio: hayFiltro
                ? 'Ningún producto coincide con el filtro'
                : 'Sin productos en "$nombreCategoria"',
            columnas: columnasTablaProducto(mostrarCategoria: false),
          ),
        ),
        if (totalPaginas > 1)
          PaginacionWidget(
            paginaActual: pagina,
            totalPaginas: totalPaginas,
            totalItems: resultado.total,
            itemsPorPagina: _tamanoPagina,
            alCambiarPagina: alCambiarPagina,
          ),
      ],
    );
  }
}
