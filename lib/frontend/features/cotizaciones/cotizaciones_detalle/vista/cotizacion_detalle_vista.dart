import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/backend/features/motos/modelo/moto.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/share/database/locator.dart';
import 'package:inventario_k1/frontend/features/motos/widgets/dialogo_motos.dart';
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

import '../../../../../../backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import '../../provider/cotizaciones_provider.dart';
import '../../widgets/dialogo/dialogo_cot_form_fields.dart';
import '../provider/cotizacion_editor_provider.dart';
import '../widgets/dialogo_cantidad_widget.dart';
import '../widgets/panel_resumen_widget.dart';
import '../widgets/seccion_datos_cliente_widget.dart';

/// Vista de detalle / creación de cotización.
///
/// [cotizacion] == null → nueva. != null → editar; ítems se cargan async.
class CotizacionDetalleVista extends ConsumerStatefulWidget {
  const CotizacionDetalleVista({super.key, this.cotizacion});

  final CotizacionResumen? cotizacion;

  @override
  ConsumerState<CotizacionDetalleVista> createState() =>
      _CotizacionDetalleVistaState();
}

class _CotizacionDetalleVistaState
    extends ConsumerState<CotizacionDetalleVista> {
  // ── Controladores UI (ciclo de vida del widget) ────────────────────────────
  late final ValueNotifier<Moto?> _motoNotifier;
  late final TextEditingController _vigenciaCtrl;
  late final TextEditingController _notasCtrl;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _motoNotifier = ValueNotifier(null);
    final cot = widget.cotizacion;
    _vigenciaCtrl = TextEditingController(text: cot?.vigenciaHasta ?? '');
    _notasCtrl = TextEditingController(text: cot?.notas ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cotizacionEditorProvider.notifier).inicializar(widget.cotizacion);
    });
  }

  @override
  void dispose() {
    _motoNotifier.dispose();
    _vigenciaCtrl.dispose();
    _notasCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Diálogos / navegación (responsabilidades exclusivas del widget) ─────────

  Future<void> _abrirFecha() async {
    final ahora = DateTime.now();
    final inicial = DateTime.tryParse(_vigenciaCtrl.text) ??
        ahora.add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: ahora,
      lastDate: ahora.add(const Duration(days: 365 * 3)),
    );
    if (picked != null && mounted) {
      _vigenciaCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  void _onBusquedaProductos(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) ref.read(cotizacionEditorProvider.notifier).buscarProductos(q);
    });
  }

  Future<void> _agregarProducto(Producto p) async {
    final notifier = ref.read(cotizacionEditorProvider.notifier);
    final error = notifier.validarAgregarProducto(p);
    if (error != null) {
      SnackBarMensaje.error(context, error);
      return;
    }
    final datos = notifier.datosDialogoProducto(p);
    final cantidad = await DialogoCantidad.mostrar(
      context,
      nombreProducto: p.nombre,
      disponible: datos.disponible,
      cantidadInicial: datos.cantidadInicial,
      etiquetaConfirmar: datos.esActualizacion ? 'Actualizar' : 'Agregar',
    );
    if (cantidad == null || !mounted) return;
    notifier.confirmarAgregarProducto(p, cantidad);
  }

  void _agregarNuevoProducto() {
    DialogoProducto.mostrar(
      context,
      proveedoresVm: locator<ProveedoresViewModel>(),
    ).then((_) => ref.invalidate(productosParaCotizacionProvider));
  }

  void _verDetalleProducto(Producto p) =>
      DialogoDetalleProductoWidget.mostrar(context, producto: p);

  void _editarProducto(Producto p) {
    DialogoProducto.mostrar(
      context,
      proveedoresVm: locator<ProveedoresViewModel>(),
      productoAEditar: p,
    ).then((_) => ref.invalidate(productosParaCotizacionProvider));
  }

  Future<void> _eliminarProductoDelCatalogo(Producto p) async {
    await DialogoConfirmarEliminar.mostrar(
      context: context,
      nombreElemento: p.nombre,
      tipoElemento: 'producto',
      onConfirmar: () async {
        final error = await ref
            .read(cotizacionEditorProvider.notifier)
            .eliminarProductoCatalogo(p);
        if (!mounted) return;
        if (error != null) {
          SnackBarMensaje.error(context, error);
        } else {
          SnackBarMensaje.success(
              context, '"${p.nombre}" eliminado del catálogo.');
        }
      },
    );
  }

  Future<void> _guardar() async {
    final esNueva = !ref.read(cotizacionEditorProvider).esEdicion;
    final notas =
        _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim();
    final error = await ref.read(cotizacionEditorProvider.notifier).guardar(
          vigencia: _vigenciaCtrl.text,
          notas: notas,
        );
    if (!mounted) return;
    if (error != null) {
      SnackBarMensaje.error(context, error);
    } else {
      SnackBarMensaje.success(
        context,
        esNueva ? 'Cotización creada correctamente.' : 'Cotización actualizada.',
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Sincroniza el AppSearch cuando el notifier carga la moto en modo edición.
    ref.listen<CotizacionEditorState>(cotizacionEditorProvider, (prev, next) {
      if (prev?.moto?.id != next.moto?.id) {
        _motoNotifier.value = next.moto;
      }
    });

    final estado = ref.watch(cotizacionEditorProvider);
    final motos =
        ref.watch(motosParaCotizacionProvider).value ?? const <Moto>[];
    final productosActivos =
        ref.watch(productosParaCotizacionProvider).value ?? const <Producto>[];
    final productosFiltrados = estado.filtrarProductos(productosActivos);

    return Scaffold(
      backgroundColor: ColoresApp.bgContent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BarraSuperior(
            guardando: estado.guardando,
            onCancelar: () => Navigator.pop(context),
            onGuardar: _guardar,
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
                            motoNotifier: _motoNotifier,
                            motos: motos,
                            vigenciaCtrl: _vigenciaCtrl,
                            notasCtrl: _notasCtrl,
                            nombreCliente: estado.nombreCliente,
                            telefono: estado.telefono,
                            onMotoSeleccionada: (moto) => ref
                                .read(cotizacionEditorProvider.notifier)
                                .seleccionarMoto(moto),
                            onAbrirFecha: _abrirFecha,
                            onAgregarMoto: () => DialogoMoto.mostrar(context)
                                .then((_) =>
                                    ref.invalidate(motosParaCotizacionProvider)),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(24, 20, 24, 12),
                          child: _EncabezadoProductos(
                            onBusqueda: _onBusquedaProductos,
                            onAgregarNuevo: _agregarNuevoProducto,
                          ),
                        ),
                      ),
                      if (productosFiltrados.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(24, 0, 24, 32),
                            child: EstadoVacioWidget(
                              icono: Icons.inventory_2_outlined,
                              textoSinDatos: 'Sin productos activos',
                              textoSinResultados:
                                  'No hay productos que coincidan.',
                              textoCTA:
                                  'Usa el botón + para agregar un producto al catálogo.',
                              hayFiltro: estado.busquedaProductos.isNotEmpty,
                            ),
                          ),
                        )
                      else
                        _SliverGrillaProductos(
                          productos: productosFiltrados,
                          onAgregar: _agregarProducto,
                          onVerDetalle: _verDetalleProducto,
                          onEditar: _editarProducto,
                          onEliminar: _eliminarProductoDelCatalogo,
                        ),
                    ],
                  ),
                ),

                // ── Derecha: panel de ítems seleccionados ──────────
                SizedBox(
                  width: 300,
                  child: PanelResumenWidget(
                    items: List.unmodifiable(estado.items),
                    subtotal: estado.subtotal,
                    iva: estado.iva,
                    total: estado.total,
                    cargandoItems: estado.cargandoItems,
                    onEliminarItem: (i) =>
                        ref.read(cotizacionEditorProvider.notifier).eliminarItem(i),
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
}

// ── Widgets privados de la vista ──────────────────────────────────────────────

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
                placeholder: 'Buscar producto por nombre, SKU o categoría...',
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

  static const double _maxAncho = 220.0;
  static const double _espaciado = 12.0;
  static const double _altura = 310.0;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: _maxAncho,
          crossAxisSpacing: _espaciado,
          mainAxisSpacing: _espaciado,
          mainAxisExtent: _altura,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            final p = productos[i];
            return TarjetaProductoWidget(
              key: ValueKey(p.id),
              producto: p,
              alTap: () => onAgregar(p),
              alVerDetalle: () => onVerDetalle(p),
              alEditar: () => onEditar(p),
              alEliminar: () => onEliminar(p),
            );
          },
          childCount: productos.length,
        ),
      ),
    );
  }
}
