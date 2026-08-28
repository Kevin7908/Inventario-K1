import 'dart:async';
import 'dart:io';

import '../../../../core/resultado.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../layout/encabezado_con_cuenta.dart';
import '../../../share/share.dart';
import '../../categorias/widgets/panel_categorias_catalogo.dart';
import '../provider/productos_provider.dart';
import '../widgets/columnas_tabla_producto.dart';
import 'producto_detalle_vista.dart';
import 'producto_formulario_vista.dart';

/// Pantalla de Productos: catálogo de repuestos en tabla.
///
/// Hospeda la navegación interna del módulo entre las tres vistas del diseño
/// —lista, detalle y formulario— sin usar rutas globales, igual que hace
/// Configuración con sus pestañas.
class ProductosVista extends ConsumerStatefulWidget {
  const ProductosVista({super.key});

  @override
  ConsumerState<ProductosVista> createState() => _ProductosVistaState();
}

/// Vista activa dentro del módulo.
enum _Pantalla { lista, detalle, formulario }

class _ProductosVistaState extends ConsumerState<ProductosVista> {
  final _busquedaController = TextEditingController();
  final _focoBusqueda = FocusNode();
  Timer? _debounce;

  _Pantalla _pantalla = _Pantalla.lista;
  Producto? _seleccionado;

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaController.dispose();
    _focoBusqueda.dispose();
    super.dispose();
  }

  void _alBuscar(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(productosProvider.notifier).buscar(query);
    });
  }

  void _verDetalle(Producto producto) => setState(() {
    _seleccionado = producto;
    _pantalla = _Pantalla.detalle;
  });

  void _nuevoProducto() => setState(() {
    _seleccionado = null;
    _pantalla = _Pantalla.formulario;
  });

  void _editar(Producto producto) => setState(() {
    _seleccionado = producto;
    _pantalla = _Pantalla.formulario;
  });

  void _volverALista() => setState(() => _pantalla = _Pantalla.lista);

  void _mostrarError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error,
          style: TipografiaApp.sobrePrimario(TipografiaApp.cuerpo),
        ),
        backgroundColor: ColoresApp.statusDanger,
      ),
    );
  }

  /// Elimina el producto abierto y regresa al catálogo.
  Future<void> _eliminar(Producto producto) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Eliminar "${producto.nombre}"?',
      mensaje:
          'Se quitará del catálogo y de los filtros. '
          'Esta acción no se puede deshacer.',
    );
    if (confirmado != true || !mounted) return;

    final resultado = await ref
        .read(productosProvider.notifier)
        .eliminar(producto.id!);
    if (!mounted) return;

    switch (resultado) {
      case Exito():
        _volverALista();
      case Fallo(:final mensaje):
        _mostrarError(mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_pantalla) {
      _Pantalla.lista => _lista(),
      _Pantalla.detalle => ProductoDetalleVista(
        producto: _seleccionado!,
        alVolver: _volverALista,
        alEditar: () => _editar(_seleccionado!),
        alEliminar: () => _eliminar(_seleccionado!),
      ),
      _Pantalla.formulario => ProductoFormularioVista(
        productoAEditar: _seleccionado,
        alCerrar: _volverALista,
      ),
    };
  }

  /// La lista no observa ningún provider: cada bloque se suscribe al suyo, así
  /// que escribir en el buscador de categorías no reconstruye la tabla ni el
  /// encabezado.
  Widget _lista() {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _focoBusqueda.requestFocus(),
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelCategorias(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _EncabezadoProductos(),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: BarraBusqueda(
                          controlador: _busquedaController,
                          focoTeclado: _focoBusqueda,
                          placeholder: 'Buscar repuesto, referencia, SKU...',
                          alCambiar: _alBuscar,
                        ),
                      ),
                      const SizedBox(width: 20),
                      BotonPrimario(
                        etiqueta: 'Nuevo producto',
                        icono: Icons.add,
                        alPresionar: _nuevoProducto,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _ChipsStock(),
                  const SizedBox(height: 16),
                  Expanded(child: _TablaProductos(alVerDetalle: _verDetalle)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Encabezado con los conteos del catálogo.
///
/// Watch propio sobre `productosResumenProvider`: solo rebuilda cuando cambian
/// los números, no cuando se filtra.
class _EncabezadoProductos extends ConsumerWidget {
  const _EncabezadoProductos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(productosResumenProvider).value;
    final total = resumen?.total ?? 0;
    final bajos = resumen?.stockBajo ?? 0;
    final agotados = resumen?.sinStock ?? 0;

    // "Stock bajo" y "agotado" son tramos distintos desde que existen los
    // chips; el subtítulo nombra el segundo solo cuando hay algo que reponer.
    final buffer = StringBuffer('$total repuestos en catálogo')
      ..write(' · $bajos con stock bajo');
    if (agotados > 0) buffer.write(' · $agotados agotados');

    return EncabezadoConCuenta(
      titulo: 'Productos',
      subtitulo: buffer.toString(),
    );
  }
}

/// Chips de filtro por estado de stock, con el conteo de cada tramo.
///
/// No están en el mockup —ahí solo se filtra por categoría—, pero el catálogo
/// se revisa sobre todo para reponer, y llegar a "lo que falta" no debería
/// obligar a recorrer la tabla. Cada chip lleva el color del semáforo que ya
/// usa `BadgeEstadoStock`, así que el filtro y la columna Estado se leen igual.
///
/// Observa el resumen y el filtro activo por separado: cambiar de chip no
/// vuelve a consultar los conteos, y que entre un producto nuevo no repinta
/// la selección.
class _ChipsStock extends ConsumerWidget {
  const _ChipsStock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activo = ref.watch(
      productosProvider.select(
        (s) => s.value?.filtroStock ?? FiltroStock.todos,
      ),
    );
    final resumen = ref.watch(conteoStockProvider).value;

    void filtrar(FiltroStock filtro) =>
        ref.read(productosProvider.notifier).filtrarPorStock(filtro);

    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        ChipFiltro(
          etiqueta: _conConteo('Todos', resumen?.total),
          seleccionado: activo == FiltroStock.todos,
          alPresionar: () => filtrar(FiltroStock.todos),
        ),
        ChipFiltro(
          etiqueta: _conConteo('En stock', resumen?.enStock),
          seleccionado: activo == FiltroStock.enStock,
          colorActivo: ColoresApp.stockOk,
          alPresionar: () => filtrar(FiltroStock.enStock),
        ),
        ChipFiltro(
          etiqueta: _conConteo('Stock bajo', resumen?.stockBajo),
          seleccionado: activo == FiltroStock.stockBajo,
          colorActivo: ColoresApp.stockLow,
          alPresionar: () => filtrar(FiltroStock.stockBajo),
        ),
        ChipFiltro(
          etiqueta: _conConteo('Agotado', resumen?.sinStock),
          seleccionado: activo == FiltroStock.sinStock,
          colorActivo: ColoresApp.stockOut,
          alPresionar: () => filtrar(FiltroStock.sinStock),
        ),
      ],
    );
  }

  /// Mientras el conteo no llega, el chip va sin número en vez de mostrar un
  /// cero que sería falso.
  static String _conConteo(String etiqueta, int? cantidad) =>
      cantidad == null ? etiqueta : '$etiqueta $cantidad';
}

/// Tabla del catálogo.
class _TablaProductos extends ConsumerWidget {
  const _TablaProductos({required this.alVerDetalle});

  final ValueChanged<Producto> alVerDetalle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(productosProvider);

    if (estado.isLoading && !estado.hasValue) {
      return const Center(
        child: CircularProgressIndicator(color: ColoresApp.goGreen),
      );
    }
    if (estado.hasError && !estado.hasValue) {
      return Center(
        child: Text(
          'Error al cargar productos: ${estado.error}',
          style: TipografiaApp.cuerpo,
        ),
      );
    }

    // Página traída de la base de datos, no un recorte en memoria.
    final productos = ref.watch(productosFiltradosProvider);
    final hayFiltro = ref.watch(hayFiltroProductosProvider);
    final pagina = ref.watch(
      productosProvider.select(
        (s) => (
          actual: s.value?.pagina ?? 0,
          total: s.value?.total ?? 0,
          paginas: s.value?.totalPaginas ?? 1,
          tamano: s.value?.tamanoPagina ?? 25,
        ),
      ),
    );

    return Column(
      children: [
        Expanded(child: _tabla(productos, hayFiltro)),
        if (pagina.paginas > 1)
          PaginacionWidget(
            paginaActual: pagina.actual,
            totalPaginas: pagina.paginas,
            totalItems: pagina.total,
            itemsPorPagina: pagina.tamano,
            alCambiarPagina: (p) =>
                ref.read(productosProvider.notifier).irAPagina(p),
          ),
      ],
    );
  }

  Widget _tabla(List<Producto> productos, bool hayFiltro) {
    return TablaGenerica<Producto>(
      items: productos,
      alPresionarFila: alVerDetalle,
      mensajeVacio: hayFiltro
          ? 'Ningún producto coincide con el filtro'
          : 'Aún no hay productos en el catálogo',
      columnas: columnasTablaProducto(),
    );
  }
}

/// El panel de categorías del catálogo, atado al filtro de la tabla.
///
/// El adaptador —traducir `Categoria` al DTO del panel, la búsqueda local y el
/// abrir/cerrar— vive en el módulo de Categorías y lo comparten esta pantalla,
/// el punto de venta y los dos editores. Aquí solo queda de qué provider sale
/// la categoría activa.
class _PanelCategorias extends ConsumerWidget {
  const _PanelCategorias();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PanelCategoriasCatalogo(
      // `select`: el panel solo rebuilda si cambia la categoría activa, no con
      // cada tecla del buscador de productos.
      seleccionada: ref.watch(
        productosProvider.select((s) => s.value?.filtroCategoriaId),
      ),
      alSeleccionar: (id) =>
          ref.read(productosProvider.notifier).filtrarPorCategoria(id),
    );
  }
}

/// Miniatura del producto, con marcador cuando no hay imagen.
///
/// Cuadrada por defecto —la de las filas de la tabla— y rectangular si se le
/// pasa [ancho]: así sirve también para la franja superior de
/// [TarjetaProducto], que es ancho completo por 120 de alto.
///
/// Vive en el módulo (no en share) porque lee un archivo del disco, y share
/// no toca dependencias externas ni el sistema de archivos.
class MiniaturaProducto extends StatelessWidget {
  const MiniaturaProducto({
    super.key,
    required this.rutaImagen,
    this.lado = 44,
    this.ancho,
    this.radio = 11,
    this.conBorde = true,
  });

  final String? rutaImagen;

  /// Alto de la miniatura, y también su ancho cuando [ancho] es `null`.
  final double lado;

  /// Ancho explícito. `double.infinity` para ocupar todo el espacio del padre.
  final double? ancho;

  final double radio;

  /// El borde estorba cuando la miniatura ya va dentro de un cuadro con el
  /// suyo, como en la tarjeta de producto.
  final bool conBorde;

  @override
  Widget build(BuildContext context) {
    final ruta = rutaImagen;
    final hayRuta = ruta != null && ruta.isNotEmpty;

    return Container(
      width: ancho ?? lado,
      height: lado,
      decoration: BoxDecoration(
        color: ColoresApp.bgInput,
        borderRadius: BorderRadius.circular(radio),
        border: conBorde ? Border.all(color: ColoresApp.border) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: hayRuta ? _imagen(context, ruta) : _marcador(),
    );
  }

  Widget _imagen(BuildContext context, String ruta) {
    // Decodifica al tamaño en que se pinta: una foto de 4000 px no tiene por
    // qué ocupar memoria completa para una miniatura de 44. Con ancho
    // infinito no hay número que pasar, así que se acota por el alto.
    final escala = MediaQuery.devicePixelRatioOf(context);
    final anchoReal = ancho ?? lado;
    final acotaPorAncho = anchoReal.isFinite;

    return Image.file(
      File(ruta),
      fit: BoxFit.cover,
      cacheWidth: acotaPorAncho ? (anchoReal * escala).round() : null,
      cacheHeight: acotaPorAncho ? null : (lado * escala).round(),
      // Sin `existsSync()`: era I/O síncrono en el build de cada fila y de cada
      // hover de tarjeta. `errorBuilder` ya cubre el archivo que no está.
      errorBuilder: (_, _, _) => _marcador(),
    );
  }

  Widget _marcador() => Icon(
    Icons.image_outlined,
    size: lado * 0.42,
    color: ColoresApp.textDisabled,
  );
}
