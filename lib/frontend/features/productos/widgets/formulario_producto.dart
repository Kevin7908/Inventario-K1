import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/categorias/modelo/categoria.dart';
import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../../backend/features/proveedores/modelo/proveedor.dart';
import '../../../../backend/features/unidades_medida/modelo/unidad_medida.dart';
import '../../../share2/share2.dart';
import '../../categorias/provider/categorias_provider.dart';
import '../../proveedores/view_model/proveedores_view_model.dart';
import '../../unidades_medida/provider/unidades_medida_provider.dart';
import '../provider/productos_provider.dart';
import 'selector_imagen_widget.dart';

/// Formulario de alta y edición de un producto.
///
/// Es el **único** sitio donde vive el formulario: lo usan tanto la página
/// [ProductoFormularioVista] del módulo de Productos como [DialogoProducto],
/// que otros módulos (cotizaciones, facturas, órdenes, categorías) abren para
/// crear un producto sin salir de su pantalla.
///
/// Sigue los tres bloques del diseño —información general, precio e inventario,
/// imagen— e integra en ellos los campos que el modelo tiene y el mockup no
/// muestra (precio de compra, precio taller, IVA, proveedor, estado).
///
/// Parámetros:
/// - [productoAEditar]: producto a modificar. Si es `null`, crea uno nuevo.
/// - [proveedoresVm]: fuente de proveedores (vive en `get_it`, no en Riverpod).
/// - [alTerminar]: se llama tras guardar con éxito, para que el contenedor
///   cierre el diálogo o vuelva a la lista.
/// - [alCancelar]: se llama al presionar "Cancelar".
class FormularioProducto extends ConsumerStatefulWidget {
  const FormularioProducto({
    super.key,
    this.productoAEditar,
    required this.proveedoresVm,
    required this.alTerminar,
    required this.alCancelar,
  });

  final Producto? productoAEditar;
  final ProveedoresViewModel proveedoresVm;
  final VoidCallback alTerminar;
  final VoidCallback alCancelar;

  bool get esEdicion => productoAEditar != null;

  @override
  ConsumerState<FormularioProducto> createState() => _FormularioProductoState();
}

class _FormularioProductoState extends ConsumerState<FormularioProducto> {
  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;

  late final TextEditingController _skuCtrl;
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _precioCompraCtrl;
  late final TextEditingController _precioVentaCtrl;
  late final TextEditingController _precioTallerCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _stockMinimoCtrl;
  late final TextEditingController _ubicacionCtrl;

  Categoria? _categoria;
  Proveedor? _proveedor;
  UnidadMedida? _unidad;
  String? _imagenRuta;
  bool _aplicaIva = false;
  bool _activo = true;

  @override
  void initState() {
    super.initState();
    final p = widget.productoAEditar;

    String num(double? v) => v == null ? '' : v.toStringAsFixed(0);

    _skuCtrl = TextEditingController(text: p?.sku ?? '');
    _nombreCtrl = TextEditingController(text: p?.nombre ?? '');
    _descripcionCtrl = TextEditingController(text: p?.descripcion ?? '');
    _precioCompraCtrl = TextEditingController(text: num(p?.precioCompra));
    _precioVentaCtrl = TextEditingController(text: num(p?.precioVenta));
    _precioTallerCtrl = TextEditingController(text: num(p?.precioVentaTaller));
    _stockCtrl = TextEditingController(text: num(p?.stockActual) );
    _stockMinimoCtrl = TextEditingController(text: num(p?.stockMinimo));
    _ubicacionCtrl = TextEditingController(text: p?.ubicacionBodega ?? '');

    _imagenRuta = p?.imagenUrl;
    _aplicaIva = p?.aplicaIva ?? false;
    _activo = p?.activo ?? true;

    if (p != null) {
      // Las listas de FK viven en providers que pueden no estar resueltos
      // durante initState; se preseleccionan tras el primer frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _preseleccionarFk(p));
    }
  }

  void _preseleccionarFk(Producto p) {
    if (!mounted) return;
    final categorias = ref.read(categoriasProvider).value?.categorias ?? const [];
    final unidades = ref.read(unidadesMedidaProvider).value?.unidades ?? const [];

    setState(() {
      _categoria =
          categorias.where((c) => c.id == p.categoriaId).firstOrNull;
      _unidad = unidades.where((u) => u.id == p.unidadMedidaId).firstOrNull;
      _proveedor = widget.proveedoresVm.proveedores
          .where((pr) => pr.id == p.proveedorId)
          .firstOrNull;
    });
  }

  @override
  void dispose() {
    _skuCtrl.dispose();
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioCompraCtrl.dispose();
    _precioVentaCtrl.dispose();
    _precioTallerCtrl.dispose();
    _stockCtrl.dispose();
    _stockMinimoCtrl.dispose();
    _ubicacionCtrl.dispose();
    super.dispose();
  }

  /// Al elegir categoría se propone un SKU, solo cuando se está creando:
  /// en edición el SKU ya existe y regenerarlo rompería referencias.
  void _alCambiarCategoria(Categoria? categoria) {
    setState(() => _categoria = categoria);
    if (categoria == null || widget.esEdicion) return;
    _skuCtrl.text =
        ref.read(productosProvider.notifier).generarSku(categoria.nombre);
  }

  void _mostrarMensaje(String texto, {required bool esError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          texto,
          style: TipografiaApp.sobrePrimario(TipografiaApp.cuerpo),
        ),
        backgroundColor:
            esError ? ColoresApp.statusDanger : ColoresApp.statusSuccess,
      ),
    );
  }

  double _aDouble(TextEditingController ctrl) =>
      double.tryParse(ctrl.text.replaceAll(',', '').trim()) ?? 0;

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final descripcion = _descripcionCtrl.text.trim();
    final ubicacion = _ubicacionCtrl.text.trim();
    final precioTaller = _precioTallerCtrl.text.trim().isEmpty
        ? null
        : _aDouble(_precioTallerCtrl);

    final producto = Producto(
      id: widget.productoAEditar?.id,
      sku: _skuCtrl.text.trim(),
      nombre: _nombreCtrl.text.trim(),
      descripcion: descripcion.isEmpty ? null : descripcion,
      categoriaId: _categoria?.id,
      categoriaNombre: _categoria?.nombre,
      unidadMedidaId: _unidad?.id,
      unidadMedidaNombre: _unidad?.nombre,
      proveedorId: _proveedor?.id,
      proveedorNombre: _proveedor?.nombre,
      precioCompra: _aDouble(_precioCompraCtrl),
      precioVenta: _aDouble(_precioVentaCtrl),
      precioVentaTaller: precioTaller,
      stockActual: _aDouble(_stockCtrl),
      stockMinimo: _aDouble(_stockMinimoCtrl),
      ubicacionBodega: ubicacion.isEmpty ? null : ubicacion,
      imagenUrl: _imagenRuta,
      aplicaIva: _aplicaIva,
      activo: _activo,
    );

    final notifier = ref.read(productosProvider.notifier);
    final error = widget.esEdicion
        ? await notifier.actualizar(producto)
        : await notifier.crear(producto);

    if (!mounted) return;

    if (error != null) {
      _mostrarMensaje(error, esError: true);
      setState(() => _guardando = false);
      return;
    }

    _mostrarMensaje(
      widget.esEdicion
          ? 'Producto actualizado correctamente'
          : 'Producto creado correctamente',
      esError: false,
    );
    widget.alTerminar();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bloqueInformacionGeneral(),
          const SizedBox(height: 18),
          _bloquePrecioInventario(),
          const SizedBox(height: 18),
          _bloqueImagen(),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              BotonSecundario(
                etiqueta: 'Cancelar',
                alPresionar: _guardando ? null : widget.alCancelar,
              ),
              const SizedBox(width: 12),
              BotonPrimario(
                etiqueta: _guardando ? 'Guardando...' : 'Guardar producto',
                icono: Icons.check,
                alPresionar: _guardando ? null : _guardar,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bloqueInformacionGeneral() {
    final categorias =
        ref.watch(categoriasProvider).value?.categorias ?? const [];
    final unidades =
        ref.watch(unidadesMedidaProvider).value?.unidades ?? const [];

    return PanelSeccion(
      titulo: 'Información general',
      icono: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Fila(
            pesos: const [2, 1],
            hijos: [
              CampoTexto(
                etiqueta: 'Nombre del repuesto *',
                controlador: _nombreCtrl,
                placeholder: 'Ej: Pastillas de freno delanteras',
                validador: (v) => (v == null || v.trim().isEmpty)
                    ? 'El nombre es obligatorio.'
                    : null,
              ),
              CampoTexto(
                etiqueta: 'Código / SKU *',
                controlador: _skuCtrl,
                placeholder: 'FRE-001',
                monoespaciado: true,
                validador: (v) => (v == null || v.trim().isEmpty)
                    ? 'El SKU es obligatorio.'
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Fila(
            hijos: [
              SelectorWidget<Categoria?>(
                etiqueta: 'Categoría',
                valor: _categoria,
                opciones: <Categoria?>[null, ...categorias],
                constructorEtiqueta: (c) => c?.nombre ?? 'Sin categoría',
                alCambiar: _alCambiarCategoria,
              ),
              SelectorWidget<UnidadMedida?>(
                etiqueta: 'Unidad de medida',
                valor: _unidad,
                opciones: <UnidadMedida?>[null, ...unidades],
                constructorEtiqueta: (u) => u?.nombre ?? 'Sin unidad',
                alCambiar: (u) => setState(() => _unidad = u),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CampoTexto(
            etiqueta: 'Descripción',
            controlador: _descripcionCtrl,
            placeholder: 'Detalles, compatibilidad, observaciones...',
            lineas: 3,
          ),
        ],
      ),
    );
  }

  Widget _bloquePrecioInventario() {
    final proveedores = widget.proveedoresVm.proveedores;

    return PanelSeccion(
      titulo: 'Precio e inventario',
      icono: Icons.sell_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Fila(
            hijos: [
              CampoTexto(
                etiqueta: 'Precio de venta *',
                controlador: _precioVentaCtrl,
                placeholder: '0',
                validador: (v) {
                  final valor =
                      double.tryParse((v ?? '').replaceAll(',', '').trim());
                  if (valor == null) return 'Ingresa un número.';
                  if (valor <= 0) return 'Debe ser mayor a 0.';
                  return null;
                },
              ),
              CampoTexto(
                etiqueta: 'Stock actual',
                controlador: _stockCtrl,
                placeholder: '0',
              ),
              CampoTexto(
                etiqueta: 'Stock mínimo',
                controlador: _stockMinimoCtrl,
                placeholder: '0',
              ),
              CampoTexto(
                etiqueta: 'Ubicación',
                controlador: _ubicacionCtrl,
                placeholder: 'Bodega A-12',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Fila(
            hijos: [
              CampoTexto(
                etiqueta: 'Precio de compra',
                controlador: _precioCompraCtrl,
                placeholder: '0',
              ),
              CampoTexto(
                etiqueta: 'Precio taller',
                controlador: _precioTallerCtrl,
                placeholder: 'Opcional',
              ),
              SelectorWidget<Proveedor?>(
                etiqueta: 'Proveedor',
                valor: _proveedor,
                opciones: <Proveedor?>[null, ...proveedores],
                constructorEtiqueta: (p) => p?.nombre ?? 'Sin proveedor',
                alCambiar: (p) => setState(() => _proveedor = p),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Interruptor(
                  etiqueta: 'Aplica IVA',
                  detalle: _aplicaIva
                      ? 'Se suma ${(kTasaIva * 100).toStringAsFixed(0)}% al precio'
                      : 'Precio sin IVA',
                  valor: _aplicaIva,
                  alCambiar: (v) => setState(() => _aplicaIva = v),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Interruptor(
                  etiqueta: 'Producto activo',
                  detalle:
                      _activo ? 'Visible en el catálogo' : 'Oculto del catálogo',
                  valor: _activo,
                  alCambiar: (v) => setState(() => _activo = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bloqueImagen() {
    return PanelSeccion(
      titulo: 'Imagen del producto',
      icono: Icons.image_outlined,
      child: SelectorImagenWidget(
        rutaActual: _imagenRuta,
        enabled: !_guardando,
        onRutaSeleccionada: (ruta) => setState(() => _imagenRuta = ruta),
      ),
    );
  }
}

/// Fila de campos con pesos configurables, que se apila en ventanas angostas.
class _Fila extends StatelessWidget {
  const _Fila({required this.hijos, this.pesos});

  final List<Widget> hijos;
  final List<int>? pesos;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < hijos.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                hijos[i],
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < hijos.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(flex: pesos?[i] ?? 1, child: hijos[i]),
            ],
          ],
        );
      },
    );
  }
}

/// Interruptor con etiqueta y línea de detalle, al estilo de los campos.
class _Interruptor extends StatelessWidget {
  const _Interruptor({
    required this.etiqueta,
    required this.detalle,
    required this.valor,
    required this.alCambiar,
  });

  final String etiqueta;
  final String detalle;
  final bool valor;
  final ValueChanged<bool> alCambiar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: ColoresApp.bgInput,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: ColoresApp.borderInput),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta, style: TipografiaApp.etiquetaCampo),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  style: TipografiaApp.caption.copyWith(
                    fontSize: 12,
                    color: ColoresApp.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            value: valor,
            onChanged: alCambiar,
            activeThumbColor: ColoresApp.goGreen,
            inactiveThumbColor: ColoresApp.textDisabled,
            inactiveTrackColor: ColoresApp.border,
          ),
        ],
      ),
    );
  }
}
