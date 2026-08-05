import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../layout/encabezado_con_cuenta.dart';
import '../../../share2/share2.dart';
import '../../categorias/provider/categorias_provider.dart';
import '../provider/productos_provider.dart';
import '../widgets/badget_estado_stock_widget.dart';
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
  Timer? _debounce;

  _Pantalla _pantalla = _Pantalla.lista;
  Producto? _seleccionado;

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return switch (_pantalla) {
      _Pantalla.lista => _lista(),
      _Pantalla.detalle => ProductoDetalleVista(
          producto: _seleccionado!,
          alVolver: _volverALista,
          alEditar: () => _editar(_seleccionado!),
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
    return Row(
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
    final resumen = ref.watch(productosResumenProvider);

    return EncabezadoConCuenta(
      titulo: 'Productos',
      subtitulo: '${resumen.total} repuestos en catálogo · '
          '${resumen.stockBajo} con stock bajo',
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

    // Lista ya calculada por el provider derivado, no por el getter en build.
    final productos = ref.watch(productosFiltradosProvider);
    final hayFiltro = ref.watch(hayFiltroProductosProvider);

    return TablaGenerica<Producto>(
      items: productos,
      alPresionarFila: alVerDetalle,
      mensajeVacio: hayFiltro
          ? 'Ningún producto coincide con el filtro'
          : 'Aún no hay productos en el catálogo',
      columnas: [
        ColumnaTabla(
          titulo: 'Producto',
          flex: 5,
          constructor: (p) => _CeldaProducto(producto: p),
        ),
        ColumnaTabla(
          titulo: 'Categoría',
          flex: 2,
          constructor: (p) => Text(
            p.categoriaNombre ?? '—',
            style: TipografiaApp.caption.copyWith(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ColumnaTabla(
          titulo: 'Precio',
          flex: 2,
          constructor: (p) => Text(
            formatearPrecio(p.precioVenta),
            style: TipografiaApp.cuerpoMedium.copyWith(
              color: ColoresApp.castletonGreen,
            ),
          ),
        ),
        ColumnaTabla(
          titulo: 'Stock',
          flex: 2,
          constructor: (p) => BadgeEstadoStock(estado: p.estadoStock),
        ),
        ColumnaTabla(
          titulo: 'Ubicación',
          flex: 2,
          constructor: (p) => Text(
            p.ubicacionBodega ?? '—',
            style: TipografiaApp.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ColumnaTabla(
          titulo: '',
          ancho: 32,
          alineacion: Alignment.centerRight,
          constructor: (_) => const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: ColoresApp.textDisabled,
          ),
        ),
      ],
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
    final categorias = ref.watch(
      categoriasProvider.select((s) => s.value?.categorias ?? const []),
    );

    final query = _busqueda.trim().toLowerCase();
    final items = [
      for (final categoria in categorias)
        if (categoria.id != null &&
            (query.isEmpty || categoria.nombre.toLowerCase().contains(query)))
          CategoriaPanelDato(
            id: categoria.id!,
            nombre: categoria.nombre,
            color: _colorDeHex(categoria.colorHex),
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

/// Convierte `#RRGGBB` en [Color]. Devuelve null si el texto no es un hex
/// válido, y el panel cae a su color por defecto.
Color? _colorDeHex(String hex) {
  final limpio = hex.replaceAll('#', '').trim();
  if (limpio.length != 6) return null;
  final valor = int.tryParse(limpio, radix: 16);
  return valor == null ? null : Color(0xFF000000 | valor);
}

/// Celda principal: miniatura + nombre + SKU monoespaciado.
class _CeldaProducto extends StatelessWidget {
  const _CeldaProducto({required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MiniaturaProducto(rutaImagen: producto.imagenUrl),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                producto.nombre,
                style: TipografiaApp.cuerpoMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                producto.sku,
                style: TipografiaApp.monoespaciada(
                  TipografiaApp.caption.copyWith(
                    fontSize: 12,
                    color: ColoresApp.textDisabled,
                  ),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
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

/// Formatea un precio como "$28.000" (separador de miles con punto).
String formatearPrecio(double valor) {
  final entero = valor.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < entero.length; i++) {
    if (i > 0 && (entero.length - i) % 3 == 0) buffer.write('.');
    buffer.write(entero[i]);
  }
  return '\$$buffer';
}
