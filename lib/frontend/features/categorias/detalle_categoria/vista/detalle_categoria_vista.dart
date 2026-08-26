import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/categorias/modelo/categoria.dart';
import '../../../../../backend/features/productos/modelo/producto.dart';
import '../../../../../core/resultado.dart';
import '../../../../share2/share2.dart';
import '../../../productos/provider/productos_provider.dart';
import '../../../productos/vista/producto_detalle_vista.dart';
import '../../../productos/vista/producto_formulario_vista.dart';
import '../widgets/tabla_productos_categoria.dart';
import '../../widgets/identidad_categoria.dart';

/// Ficha de una categoría: sus datos y la tabla de productos que contiene.
///
/// Es una página dentro del módulo, no una ruta: `CategoriasVista` la muestra
/// en lugar del catálogo y vuelve con [alVolver], igual que hace Productos.
///
/// Los productos se abren con las **mismas páginas** del módulo de Productos
/// —[ProductoDetalleVista] y [ProductoFormularioVista]—, no con los diálogos
/// legacy: la ficha de un producto debe verse igual se llegue desde donde se
/// llegue. Por eso esta vista hospeda su propia navegación interna.
class DetalleCategoriaVista extends ConsumerStatefulWidget {
  const DetalleCategoriaVista({
    super.key,
    required this.categoria,
    required this.alVolver,
  });

  final Categoria categoria;
  final VoidCallback alVolver;

  @override
  ConsumerState<DetalleCategoriaVista> createState() =>
      _DetalleCategoriaVistaState();
}

/// Pantalla activa dentro de la ficha de categoría.
enum _Pantalla { productos, detalleProducto, formularioProducto }

class _DetalleCategoriaVistaState extends ConsumerState<DetalleCategoriaVista> {
  final _busquedaController = TextEditingController();
  final _focoBusqueda = FocusNode();
  Timer? _debounce;

  String _busqueda = '';
  FiltroStock _filtroStock = FiltroStock.todos;
  int _pagina = 0;

  _Pantalla _pantalla = _Pantalla.productos;
  Producto? _seleccionado;

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaController.dispose();
    _focoBusqueda.dispose();
    super.dispose();
  }

  void _alBuscar(String texto) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() {
        _busqueda = texto.trim();
        _pagina = 0;
      });
    });
  }

  void _verProducto(Producto producto) => setState(() {
        _seleccionado = producto;
        _pantalla = _Pantalla.detalleProducto;
      });

  void _editarProducto(Producto producto) => setState(() {
        _seleccionado = producto;
        _pantalla = _Pantalla.formularioProducto;
      });

  void _nuevoProducto() => setState(() {
        _seleccionado = null;
        _pantalla = _Pantalla.formularioProducto;
      });

  void _volverAProductos() => setState(() => _pantalla = _Pantalla.productos);

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

  Future<void> _eliminarProducto(Producto producto) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Eliminar "${producto.nombre}"?',
      mensaje: 'Se quitará del catálogo y de esta categoría. '
          'Esta acción no se puede deshacer.',
    );
    if (confirmado != true || !mounted) return;

    final resultado =
        await ref.read(productosProvider.notifier).eliminar(producto.id!);
    if (!mounted) return;

    switch (resultado) {
      case Exito():
        _volverAProductos();
      case Fallo(:final mensaje):
        _mostrarError(mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_pantalla) {
      _Pantalla.productos => _listaProductos(),
      _Pantalla.detalleProducto => ProductoDetalleVista(
          producto: _seleccionado!,
          alVolver: _volverAProductos,
          alEditar: () => _editarProducto(_seleccionado!),
          alEliminar: () => _eliminarProducto(_seleccionado!),
        ),
      _Pantalla.formularioProducto => ProductoFormularioVista(
          productoAEditar: _seleccionado,
          alCerrar: _volverAProductos,
        ),
    };
  }

  Widget _listaProductos() {
    final categoria = widget.categoria;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _focoBusqueda.requestFocus(),
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BotonVolver(
              etiqueta: 'Volver a categorías',
              alPresionar: widget.alVolver,
            ),
            const SizedBox(height: 18),
            _Encabezado(
              categoria: categoria,
              alAgregarProducto: _nuevoProducto,
            ),
            const SizedBox(height: 22),
            BarraBusqueda(
              controlador: _busquedaController,
              focoTeclado: _focoBusqueda,
              placeholder: 'Buscar en ${categoria.nombre}...',
              alCambiar: _alBuscar,
            ),
            const SizedBox(height: 16),
            ChipsFiltroStock(
              filtroActual: _filtroStock,
              alCambiar: (f) => setState(() {
                _filtroStock = f;
                _pagina = 0;
              }),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: TablaProductosCategoria(
                categoriaId: categoria.id!,
                nombreCategoria: categoria.nombre,
                busqueda: _busqueda,
                filtroStock: _filtroStock,
                pagina: _pagina,
                alCambiarPagina: (p) => setState(() => _pagina = p),
                alVerProducto: _verProducto,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marcador, nombre, descripción y acción principal de la categoría.
class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.categoria,
    required this.alAgregarProducto,
  });

  final Categoria categoria;
  final VoidCallback alAgregarProducto;

  @override
  Widget build(BuildContext context) {
    final descripcion = categoria.descripcion?.trim() ?? '';

    return Row(
      children: [
        MarcadorIdentidad(
          inicial: inicialDe(categoria.nombre),
          color: IdentidadCategoria.color,
          lado: 50,
          radio: 14,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(categoria.nombre, style: TipografiaApp.heading1),
              const SizedBox(height: 4),
              Text(
                descripcion.isEmpty ? 'Sin descripción' : descripcion,
                style: TipografiaApp.subtituloPagina,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        BotonPrimario(
          etiqueta: 'Agregar producto',
          icono: Icons.add,
          alPresionar: alAgregarProducto,
        ),
      ],
    );
  }
}
