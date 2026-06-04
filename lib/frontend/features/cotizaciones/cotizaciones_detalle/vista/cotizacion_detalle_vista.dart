import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/backend/features/motos/modelo/moto.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/share/database/locator.dart';
import 'package:inventario_k1/frontend/features/motos/widgets/dialogo_motos.dart';
import 'package:inventario_k1/frontend/features/productos/provider/productos_provider.dart';
import 'package:inventario_k1/frontend/features/productos/widgets/dialogo_detalle_producto_widget.dart';
import 'package:inventario_k1/frontend/features/productos/widgets/dialogo_producto_widget.dart';
import 'package:inventario_k1/frontend/features/productos/widgets/tarjeta_producto_widget.dart';
import 'package:inventario_k1/frontend/features/proveedores/view_model/proveedores_view_model.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/widgets/botones/boton_mas_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/dialogos/dialogo_confirmar_eliminar_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/input/barra_busqueda_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/output/estado_vacio_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/output/snack_bar_mensaje.dart';
import 'package:inventario_k1/frontend/share/widgets/top_bar_widget.dart';

import '../../../../../../backend/features/cotizaciones/enum/enum_cotizacion.dart';
import '../../../../../../backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import '../../provider/cotizaciones_provider.dart';
import '../../widgets/dialogo/dialogo_cot_form_fields.dart';
import '../../widgets/dialogo/dialogo_cot_items_tabla.dart';
import '../widgets/dialogo_cantidad_widget.dart';
import '../widgets/panel_resumen_widget.dart';
import '../widgets/seccion_datos_cliente_widget.dart';

/// Vista de detalle / creación de cotización.
///
/// [cotizacion] == null → nueva. != null → editar; ítems se cargan async.
class CotizacionDetalleVista extends ConsumerStatefulWidget {
  const CotizacionDetalleVista({super.key, this.cotizacion});

  final CotizacionResumen? cotizacion;

  bool get esEdicion => cotizacion != null;

  @override
  ConsumerState<CotizacionDetalleVista> createState() =>
      _CotizacionDetalleVistaState();
}

class _CotizacionDetalleVistaState
    extends ConsumerState<CotizacionDetalleVista> {
  // ── Controladores ──────────────────────────────────────────────────────────
  late final ValueNotifier<Moto?> _motoNotifier;
  late final TextEditingController _vigenciaCtrl;
  late final TextEditingController _notasCtrl;

  // ── Estado local ───────────────────────────────────────────────────────────
  String _nombreCliente = '';
  String _telefono = '';
  final List<CotItemDraft> _items = [];
  /// Snapshot del último guardado; permite calcular el delta de stock al actualizar.
  final List<CotItemDraft> _itemsOriginales = [];
  String _busquedaProductos = '';
  Timer? _debounce;
  bool _guardando = false;
  bool _cargandoItems = false;

  /// null = aún no guardada; non-null = ya tiene ID en BD → modo actualizar.
  int? _cotizacionId;

  // ── Helpers de stock ───────────────────────────────────────────────────────

  int _cantidadEnCarrito(int productId) => _items
      .where((i) => i.referenciaId == productId)
      .fold(0, (s, i) => s + i.cantidad.toInt());

  /// Stock restante que el usuario todavía puede agregar para este producto.
  int _stockDisponible(Producto p) =>
      (p.stockActual.toInt() - _cantidadEnCarrito(p.id ?? -1)).clamp(0, 999999);

  // ── Computados ─────────────────────────────────────────────────────────────
  int get _subtotal => _items.fold(0, (s, i) => s + i.subtotal);
  int get _iva       => (_subtotal * kTasaIva).round();
  int get _total     => _subtotal + _iva;

  // ── Ciclo de vida ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _motoNotifier = ValueNotifier(null);
    _vigenciaCtrl = TextEditingController();
    _notasCtrl    = TextEditingController();

    if (widget.esEdicion) {
      final cot = widget.cotizacion!;
      _cotizacionId  = cot.id;
      _vigenciaCtrl.text = cot.vigenciaHasta;
      _notasCtrl.text    = cot.notas ?? '';
      _nombreCliente     = cot.nombreCliente;
      _telefono          = cot.telefonoCliente ?? '';
      _cargandoItems     = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _preCargarDatos());
    }
  }

  @override
  void dispose() {
    _motoNotifier.dispose();
    _vigenciaCtrl.dispose();
    _notasCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Carga asíncrona en modo edición ───────────────────────────────────────

  Future<void> _preCargarDatos() async {
    final cot = widget.cotizacion!;
    try {
      final motos = await ref.read(motosParaCotizacionProvider.future);
      if (!mounted) return;
      _motoNotifier.value =
          motos.where((m) => m.id == cot.motoId).firstOrNull;

      final detalle = await ref
          .read(repositorioCotizacionesProvider)
          .obtenerDetalle(cot.id);
      if (!mounted) return;

      setState(() {
        for (final item in detalle.items) {
          final draft = CotItemDraft(
            tipo:           item.tipoItem,
            referenciaId:   item.referenciaId,
            descripcion:    item.descripcion,
            cantidad:       item.cantidad,
            precioUnitario: item.precioUnitario,
          );
          _items.add(draft);
          // Copia inmutable del estado guardado en BD (para delta de stock).
          _itemsOriginales.add(CotItemDraft(
            tipo:           draft.tipo,
            referenciaId:   draft.referenciaId,
            descripcion:    draft.descripcion,
            cantidad:       draft.cantidad,
            precioUnitario: draft.precioUnitario,
          ));
        }
        _cargandoItems = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoItems = false);
    }
  }

  // ── Handlers ───────────────────────────────────────────────────────────────

  void _onMotoSeleccionada(Moto? moto) {
    if (moto == null) return;
    final clientes = ref.read(clientesParaCotizacionProvider).value ?? [];
    final cliente  = clientes.where((c) => c.id == moto.clienteId).firstOrNull;
    setState(() {
      _nombreCliente = moto.nombreCliente ?? '';
      _telefono      = cliente?.telefono ?? '';
    });
  }

  Future<void> _abrirFecha() async {
    final ahora   = DateTime.now();
    final inicial = DateTime.tryParse(_vigenciaCtrl.text) ??
        ahora.add(const Duration(days: 30));
    final picked = await showDatePicker(
      context:     context,
      initialDate: inicial,
      firstDate:   ahora,
      lastDate:    ahora.add(const Duration(days: 365 * 3)),
    );
    if (picked != null && mounted) {
      setState(() {
        _vigenciaCtrl.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _onBusquedaProductos(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _busquedaProductos = q.trim());
    });
  }

  /// Valida stock y muestra el diálogo de cantidad antes de agregar al carrito.
  /// Si el producto ya está en el carrito, la nueva cantidad REEMPLAZA a la anterior.
  Future<void> _agregarProducto(Producto p) async {
    if (p.stockActual <= 0) {
      SnackBarMensaje.error(
          context, '"${p.nombre}" no tiene stock disponible.');
      return;
    }

    final enCarrito      = _cantidadEnCarrito(p.id ?? -1);
    final yaEstaEnCarrito = enCarrito > 0;

    // Si ya está en el carrito mostramos el stock completo (vamos a reemplazar).
    final disponible = yaEstaEnCarrito
        ? p.stockActual.toInt()
        : _stockDisponible(p);

    if (disponible <= 0) {
      SnackBarMensaje.error(
          context, 'Ya tienes todo el stock de "${p.nombre}" en el carrito.');
      return;
    }

    final cantidad = await DialogoCantidad.mostrar(
      context,
      nombreProducto:    p.nombre,
      disponible:        disponible,
      cantidadInicial:   yaEstaEnCarrito ? enCarrito : 1,
      etiquetaConfirmar: yaEstaEnCarrito ? 'Actualizar' : 'Agregar',
    );
    if (cantidad == null || !mounted) return;

    setState(() {
      final idx = _items.indexWhere((i) => i.referenciaId == p.id);
      if (idx >= 0) {
        _items[idx].cantidad = cantidad.toDouble(); // reemplazar, no acumular
      } else {
        _items.add(CotItemDraft(
          tipo:           TipoItemCotizacion.producto,
          referenciaId:   p.id,
          descripcion:    p.nombre,
          cantidad:       cantidad.toDouble(),
          precioUnitario: p.precioVenta.round(),
        ));
      }
    });
  }

  void _agregarNuevoProducto() {
    DialogoProducto.mostrar(
      context,
      proveedoresVm: locator<ProveedoresViewModel>(),
    ).then((_) => ref.invalidate(productosParaCotizacionProvider));
  }

  void _verDetalleProducto(Producto p) {
    DialogoDetalleProductoWidget.mostrar(context, producto: p);
  }

  void _editarProducto(Producto p) {
    DialogoProducto.mostrar(
      context,
      proveedoresVm:   locator<ProveedoresViewModel>(),
      productoAEditar: p,
    ).then((_) => ref.invalidate(productosParaCotizacionProvider));
  }

  Future<void> _eliminarProductoDelCatalogo(Producto p) async {
    if (p.id == null) return;
    await DialogoConfirmarEliminar.mostrar(
      context:        context,
      nombreElemento: p.nombre,
      tipoElemento:   'producto',
      onConfirmar: () async {
        try {
          await ref.read(repositorioProductosProvider).eliminar(p.id!);
          if (!mounted) return;
          setState(() {
            _items.removeWhere((i) => i.referenciaId == p.id);
            _itemsOriginales.removeWhere((i) => i.referenciaId == p.id);
          });
          ref.invalidate(productosParaCotizacionProvider);
          SnackBarMensaje.success(context, '"${p.nombre}" eliminado del catálogo.');
        } catch (e) {
          if (!mounted) return;
          SnackBarMensaje.error(context, 'No se pudo eliminar: $e');
        }
      },
    );
  }

  Future<void> _guardar() async {
    final moto = _motoNotifier.value;

    if (_cotizacionId == null && moto == null) {
      SnackBarMensaje.error(context, 'Selecciona una moto para continuar.');
      return;
    }
    if (_vigenciaCtrl.text.isEmpty) {
      SnackBarMensaje.error(context, 'Ingresa la fecha de vigencia.');
      return;
    }

    setState(() => _guardando = true);

    final notas      = _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim();
    final itemsDraft = _items.map((i) => i.toItemDraft()).toList();

    if (_cotizacionId == null) {
      // ── Nueva cotización ─────────────────────────────────────────────────
      try {
        final nuevoId = await ref.read(repositorioCotizacionesProvider).crear(
          clienteId:     moto!.clienteId,
          motoId:        moto.id,
          vigenciaHasta: _vigenciaCtrl.text,
          notas:         notas,
          items:         itemsDraft,
        );
        if (!mounted) return;

        // Descontar stock para todos los ítems guardados.
        await _ajustarStocks(_items, factor: -1);
        if (!mounted) return;

        _actualizarItemsOriginales();
        setState(() {
          _cotizacionId = nuevoId;
          _guardando    = false;
        });
        SnackBarMensaje.success(context, 'Cotización creada correctamente.');
      } catch (e) {
        if (!mounted) return;
        setState(() => _guardando = false);
        SnackBarMensaje.error(context, 'Error al crear: $e');
      }
    } else {
      // ── Actualizar cotización existente ──────────────────────────────────
      final error = await ref.read(cotizacionesProvider.notifier).actualizar(
        id:            _cotizacionId!,
        clienteId:     moto?.clienteId ?? widget.cotizacion?.clienteId,
        motoId:        moto?.id        ?? widget.cotizacion?.motoId,
        vigenciaHasta: _vigenciaCtrl.text,
        notas:         notas,
        items:         itemsDraft,
      );
      if (!mounted) return;
      if (error != null) {
        setState(() => _guardando = false);
        SnackBarMensaje.error(context, error);
        return;
      }

      // Restaurar stock de los ítems anteriores y descontar los nuevos.
      await _ajustarStocks(_itemsOriginales, factor: 1);
      await _ajustarStocks(_items,           factor: -1);
      if (!mounted) return;

      _actualizarItemsOriginales();
      setState(() => _guardando = false);
      SnackBarMensaje.success(context, 'Cotización actualizada.');
    }
  }

  /// Ajusta el stock de cada producto en [items] multiplicando la cantidad
  /// por [factor] (+1 para restaurar, -1 para descontar).
  Future<void> _ajustarStocks(List<CotItemDraft> items, {required int factor}) async {
    final repo = ref.read(repositorioProductosProvider);
    for (final item in items) {
      if (item.tipo != TipoItemCotizacion.producto) continue;
      if (item.referenciaId == null) continue;
      await repo.ajustarStock(item.referenciaId!, item.cantidad * factor);
    }
    // Refresca la lista de productos para que el grid muestre el stock real.
    ref.invalidate(productosParaCotizacionProvider);
  }

  /// Reemplaza `_itemsOriginales` con una copia profunda del estado actual.
  void _actualizarItemsOriginales() {
    _itemsOriginales
      ..clear()
      ..addAll(_items.map((i) => CotItemDraft(
            tipo:           i.tipo,
            referenciaId:   i.referenciaId,
            descripcion:    i.descripcion,
            cantidad:       i.cantidad,
            precioUnitario: i.precioUnitario,
          )));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final motos = ref.watch(motosParaCotizacionProvider).value ?? const <Moto>[];
    final productosActivos =
        ref.watch(productosParaCotizacionProvider).value ?? const <Producto>[];

    final productosFiltrados = _filtrarProductos(productosActivos);

    return Scaffold(
      backgroundColor: ColoresApp.bgContent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BarraSuperior(
            guardando: _guardando,
            onCancelar: () => Navigator.pop(context),
            onGuardar:  _guardar,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Izquierda: formulario + grid de productos ──────
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                          child: SeccionDatosClienteWidget(
                            motoNotifier:       _motoNotifier,
                            motos:              motos,
                            vigenciaCtrl:       _vigenciaCtrl,
                            notasCtrl:          _notasCtrl,
                            nombreCliente:      _nombreCliente,
                            telefono:           _telefono,
                            onMotoSeleccionada: _onMotoSeleccionada,
                            onAbrirFecha:       _abrirFecha,
                            onAgregarMoto: () => DialogoMoto.mostrar(context)
                                .then((_) =>
                                    ref.invalidate(motosParaCotizacionProvider)),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                          child: _EncabezadoProductos(
                            onBusqueda:     _onBusquedaProductos,
                            onAgregarNuevo: _agregarNuevoProducto,
                          ),
                        ),
                      ),
                      if (productosFiltrados.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                            child: EstadoVacioWidget(
                              icono: Icons.inventory_2_outlined,
                              textoSinDatos: 'Sin productos activos',
                              textoSinResultados:
                                  'No hay productos que coincidan.',
                              textoCTA:
                                  'Usa el botón + para agregar un producto al catálogo.',
                              hayFiltro: _busquedaProductos.isNotEmpty,
                            ),
                          ),
                        )
                      else
                        _SliverGrillaProductos(
                          productos:    productosFiltrados,
                          onAgregar:    _agregarProducto,
                          onVerDetalle: _verDetalleProducto,
                          onEditar:     _editarProducto,
                          onEliminar:   _eliminarProductoDelCatalogo,
                        ),
                    ],
                  ),
                ),

                // ── Derecha: panel de ítems seleccionados ──────────
                SizedBox(
                  width: 300,
                  child: PanelResumenWidget(
                    items:         List.unmodifiable(_items),
                    subtotal:      _subtotal,
                    iva:           _iva,
                    total:         _total,
                    cargandoItems: _cargandoItems,
                    onEliminarItem: (i) => setState(() => _items.removeAt(i)),
                    onImprimir: () => SnackBarMensaje.success(
                        context, 'Próximamente: Vista previa PDF.'),
                    onReservar: () {},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Producto> _filtrarProductos(List<Producto> todos) {
    if (_busquedaProductos.isEmpty) return todos;
    final q = _busquedaProductos.toLowerCase();
    return todos
        .where((p) =>
            p.nombre.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q) ||
            (p.categoriaNombre?.toLowerCase().contains(q) ?? false))
        .toList();
  }
}

// ── Widgets privados ──────────────────────────────────────────────────────────

class _BarraSuperior extends StatelessWidget {
  const _BarraSuperior({
    required this.guardando,
    required this.onCancelar,
    required this.onGuardar,
  });

  final bool guardando;
  final VoidCallback onCancelar;
  final VoidCallback onGuardar;

  @override
  Widget build(BuildContext context) {
    return TopBarWidget(
      titulo: 'Cotizaciones',
      mostrarBotonVolver: true,
      alPresionarVolver: onCancelar,
      accionesSufijo: ElevatedButton.icon(
        onPressed: guardando ? null : onGuardar,
        icon: guardando
            ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save_outlined, size: 18),
        label: const Text('Guardar cotización'),
        style: ElevatedButton.styleFrom(
          backgroundColor: ColoresApp.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

class _EncabezadoProductos extends StatelessWidget {
  const _EncabezadoProductos({
    required this.onBusqueda,
    required this.onAgregarNuevo,
  });

  final ValueChanged<String> onBusqueda;
  final VoidCallback onAgregarNuevo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CotSeccionLabel(
          icono: Icons.shopping_cart_outlined,
          label: 'AGREGAR PRODUCTOS A LA COTIZACIÓN',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: BarraBusquedaWidget(
                placeholder:
                    'Buscar producto por nombre, SKU o categoría...',
                alCambiar: onBusqueda,
              ),
            ),
            const SizedBox(width: 8),
            BotonMasWidget(onPressed: onAgregarNuevo),
          ],
        ),
      ],
    );
  }
}

/// Grid lazy de productos para seleccionar.
/// Tap = agregar al carrito; botones de ojo/editar/eliminar gestionan el producto.
class _SliverGrillaProductos extends StatelessWidget {
  const _SliverGrillaProductos({
    required this.productos,
    required this.onAgregar,
    required this.onVerDetalle,
    required this.onEditar,
    required this.onEliminar,
  });

  final List<Producto> productos;
  final ValueChanged<Producto> onAgregar;
  final ValueChanged<Producto> onVerDetalle;
  final ValueChanged<Producto> onEditar;
  final ValueChanged<Producto> onEliminar;

  static const double _maxAncho  = 220.0;
  static const double _espaciado = 12.0;
  static const double _altura    = 310.0;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: _maxAncho,
          crossAxisSpacing:   _espaciado,
          mainAxisSpacing:    _espaciado,
          mainAxisExtent:     _altura,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            final p = productos[i];
            return TarjetaProductoWidget(
              key:          ValueKey(p.id),
              producto:     p,
              alTap:        () => onAgregar(p),
              alVerDetalle: () => onVerDetalle(p),
              alEditar:     () => onEditar(p),
              alEliminar:   () => onEliminar(p),
            );
          },
          childCount: productos.length,
        ),
      ),
    );
  }
}
