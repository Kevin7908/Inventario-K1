import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../layout/encabezado_con_cuenta.dart';
import '../../../share2/share2.dart';
import '../../categorias/provider/categorias_provider.dart';
import '../provider/productos_provider.dart';
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

  Widget _lista() {
    final estadoAsync = ref.watch(productosProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _encabezado(estadoAsync.value),
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
          _ChipsCategoria(
            seleccionada: estadoAsync.value?.filtroCategoriaId,
            alSeleccionar: (id) =>
                ref.read(productosProvider.notifier).filtrarPorCategoria(id),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: estadoAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: ColoresApp.goGreen),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Error al cargar productos: $e',
                  style: TipografiaApp.cuerpo,
                ),
              ),
              data: (estado) => _tabla(estado),
            ),
          ),
        ],
      ),
    );
  }

  Widget _encabezado(ProductosState? estado) {
    final total = estado?.todos.length ?? 0;
    final bajos = estado?.todos
            .where((p) => p.estadoStock != EstadoStock.enStock)
            .length ??
        0;

    return EncabezadoConCuenta(
      titulo: 'Productos',
      subtitulo:
          '$total repuestos en catálogo · $bajos con stock bajo',
    );
  }

  Widget _tabla(ProductosState estado) {
    final productos = estado.filtrados;
    final hayFiltro =
        estado.busqueda.isNotEmpty || estado.filtroCategoriaId != null;

    return TablaGenerica<Producto>(
      items: productos,
      alPresionarFila: _verDetalle,
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
          constructor: (p) => _ChipStock(producto: p),
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

/// Chips de categoría. "Todas" limpia el filtro.
class _ChipsCategoria extends ConsumerWidget {
  const _ChipsCategoria({
    required this.seleccionada,
    required this.alSeleccionar,
  });

  final int? seleccionada;
  final ValueChanged<int?> alSeleccionar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categorias = ref.watch(categoriasProvider).value?.categorias ?? const [];

    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        ChipFiltro(
          etiqueta: 'Todas',
          icono: Icons.grid_view_rounded,
          seleccionado: seleccionada == null,
          alPresionar: () => alSeleccionar(null),
        ),
        for (final categoria in categorias)
          ChipFiltro(
            etiqueta: categoria.nombre,
            seleccionado: seleccionada == categoria.id,
            alPresionar: () => alSeleccionar(categoria.id),
          ),
      ],
    );
  }
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

/// Chip de estado de stock, con el color del semáforo del diseño.
class _ChipStock extends StatelessWidget {
  const _ChipStock({required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context) {
    final (etiqueta, color, fondo) = switch (producto.estadoStock) {
      EstadoStock.enStock => (
          'En stock',
          ColoresApp.stockOk,
          ColoresApp.statusSuccessBg,
        ),
      EstadoStock.stockBajo => (
          'Stock bajo',
          ColoresApp.stockLow,
          ColoresApp.statusWarningBg,
        ),
      EstadoStock.sinStock => (
          'Agotado',
          ColoresApp.stockOut,
          ColoresApp.statusDangerBg,
        ),
    };

    return IndicadorEstado(
      etiqueta: etiqueta,
      color: color,
      colorFondo: fondo,
      conPunto: true,
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
    final hayImagen = ruta != null && ruta.isNotEmpty && File(ruta).existsSync();

    return Container(
      width: lado,
      height: lado,
      decoration: BoxDecoration(
        color: ColoresApp.bgInput,
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(color: ColoresApp.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: hayImagen
          ? Image.file(
              File(ruta),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _marcador(),
            )
          : _marcador(),
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
