import 'dart:async';
import 'dart:io';

import '../../../../core/resultado.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../layout/encabezado_con_cuenta.dart';
import '../../../share2/share2.dart';
import '../../../../backend/features/categorias/modelo/categoria.dart';
import '../../categorias/provider/categorias_provider.dart';
import '../../categorias/vista/categorias_vistas.dart';
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
                  const SizedBox(height: 18),
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

    return EncabezadoConCuenta(
      titulo: 'Productos',
      subtitulo: '$total repuestos en catálogo · $bajos con stock bajo',
    );
  }
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

/// Adaptador entre `categoriasProvider` y [PanelCategorias].
///
/// Traduce el modelo de dominio al DTO del panel y aplica la búsqueda local
/// de categorías. "Todas" —que pinta el propio panel— limpia el filtro.
/// El estado del panel (abierto/cerrado y su búsqueda) vive aquí y no en la
/// página: es UI local, y tenerlo arriba hacía que teclear una categoría
/// reconstruyera también la tabla y el encabezado.
class _PanelCategorias extends ConsumerStatefulWidget {
  const _PanelCategorias();

  @override
  ConsumerState<_PanelCategorias> createState() => _PanelCategoriasState();
}

class _PanelCategoriasState extends ConsumerState<_PanelCategorias> {
  final _controladorBusqueda = TextEditingController();
  String _busqueda = '';
  bool _expandido = true;

  @override
  void dispose() {
    _controladorBusqueda.dispose();
    super.dispose();
  }

  /// Contrae o expande el panel.
  ///
  /// Al contraerlo limpia su búsqueda: en la tira de íconos no se ve el
  /// buscador, y dejar una lista recortada sin explicar por qué confunde.
  void _alternar() => setState(() {
    _expandido = !_expandido;
    if (!_expandido) {
      _busqueda = '';
      _controladorBusqueda.clear();
    }
  });

  @override
  Widget build(BuildContext context) {
    // `select` en ambos: el panel solo rebuilda si cambia la categoría activa
    // o la lista de categorías, no con cada tecla del buscador de productos.
    final seleccionada = ref.watch(
      productosProvider.select((s) => s.value?.filtroCategoriaId),
    );
    final categorias =
        ref.watch(catalogoCategoriasProvider).value ?? const <Categoria>[];

    final query = _busqueda.trim().toLowerCase();
    final items = [
      for (final categoria in categorias)
        if (categoria.id != null &&
            (query.isEmpty || categoria.nombre.toLowerCase().contains(query)))
          CategoriaPanelDato(
            id: categoria.id!,
            nombre: categoria.nombre,
            color: colorDeHex(categoria.colorHex),
          ),
    ];

    return PanelCategorias(
      categorias: items,
      seleccionada: seleccionada,
      alSeleccionar: (id) =>
          ref.read(productosProvider.notifier).filtrarPorCategoria(id),
      expandido: _expandido,
      alAlternar: _alternar,
      controladorBusqueda: _controladorBusqueda,
      alBuscar: (texto) => setState(() => _busqueda = texto),
    );
  }
}

/// Miniatura cuadrada del producto, con marcador cuando no hay imagen.
///
/// Vive en el módulo (no en share2) porque lee un archivo del disco, y share2
/// no toca dependencias externas ni el sistema de archivos.
class MiniaturaProducto extends StatelessWidget {
  const MiniaturaProducto({
    super.key,
    required this.rutaImagen,
    this.lado = 44,
    this.radio = 11,
  });

  final String? rutaImagen;
  final double lado;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final ruta = rutaImagen;
    final hayRuta = ruta != null && ruta.isNotEmpty;

    return Container(
      width: lado,
      height: lado,
      decoration: BoxDecoration(
        color: ColoresApp.bgInput,
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(color: ColoresApp.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: hayRuta ? _imagen(context, ruta) : _marcador(),
    );
  }

  Widget _imagen(BuildContext context, String ruta) {
    // `cacheWidth` decodifica al tamaño en que se pinta: una foto de 4000 px no
    // tiene por qué ocupar memoria completa para una miniatura de 44.
    final escala = MediaQuery.devicePixelRatioOf(context);

    return Image.file(
      File(ruta),
      fit: BoxFit.cover,
      cacheWidth: (lado * escala).round(),
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
