import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/frontend/features/productos/widgets/componentes_formulario_widget.dart';
import 'package:provider/provider.dart';

import '../../../../backend/features/categorias/modelo/categoria.dart';
import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../../backend/features/proveedores/modelo/proveedor.dart';
import '../../../../backend/features/unidades_medida/modelo/unidad_medida.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../categorias/provider/categorias_provider.dart';
import '../../proveedores/view_model/proveedores_view_model.dart';
import '../../unidades_medida/provider/unidades_medida_provider.dart';
import '../provider/productos_provider.dart';

class DialogoProducto extends ConsumerStatefulWidget {
  const DialogoProducto({
    super.key,
    this.productoAEditar,
    required this.proveedoresVm,
  });

  final Producto? productoAEditar;
  final ProveedoresViewModel proveedoresVm;

  bool get esEdicion => productoAEditar != null;

  static Future<void> mostrar(
    BuildContext context, {
    required ProveedoresViewModel proveedoresVm,
    Producto? productoAEditar,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider<ProveedoresViewModel>.value(
        value: proveedoresVm,
        child: DialogoProducto(
          productoAEditar: productoAEditar,
          proveedoresVm: proveedoresVm,
        ),
      ),
    );
  }

  @override
  ConsumerState<DialogoProducto> createState() => _DialogoProductoState();
}

class _DialogoProductoState extends ConsumerState<DialogoProducto> {
  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;

  // Controllers de texto
  late final TextEditingController _skuCtrl;
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _precioCompraCtrl;
  late final TextEditingController _precioVentaCtrl;
  late final TextEditingController _precioTallerCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _stockMinimoCtrl;
  late final TextEditingController _ubicacionCtrl;

  // ValueNotifiers — granulares para evitar reconstrucciones del formulario completo
  late final ValueNotifier<Categoria?> _categoriaNotifier;
  late final ValueNotifier<Proveedor?> _proveedorNotifier;
  late final ValueNotifier<UnidadMedida?> _unidadNotifier;
  late final ValueNotifier<String?> _imagenRutaNotifier;
  late final ValueNotifier<bool>    _aplicaIvaNotifier;
  late final ValueNotifier<bool>    _activoNotifier;

  @override
  void initState() {
    super.initState();
    final p = widget.productoAEditar;

    _skuCtrl          = TextEditingController(text: p?.sku ?? '');
    _nombreCtrl       = TextEditingController(text: p?.nombre ?? '');
    _descripcionCtrl  = TextEditingController(text: p?.descripcion ?? '');
    _precioCompraCtrl = TextEditingController(
        text: p?.precioCompra.toStringAsFixed(0) ?? '');
    _precioVentaCtrl  = TextEditingController(
        text: p?.precioVenta.toStringAsFixed(0) ?? '');
    _precioTallerCtrl = TextEditingController(
        text: p?.precioVentaTaller?.toStringAsFixed(0) ?? '');
    _stockCtrl        = TextEditingController(
        text: p?.stockActual.toStringAsFixed(0) ?? '0');
    _stockMinimoCtrl  = TextEditingController(
        text: p?.stockMinimo.toStringAsFixed(0) ?? '0');
    _ubicacionCtrl    = TextEditingController(text: p?.ubicacionBodega ?? '');

    _categoriaNotifier  = ValueNotifier<Categoria?>(null);
    _proveedorNotifier  = ValueNotifier<Proveedor?>(null);
    _unidadNotifier     = ValueNotifier<UnidadMedida?>(null);
    _imagenRutaNotifier = ValueNotifier<String?>(p?.imagenUrl);
    _aplicaIvaNotifier  = ValueNotifier<bool>(p?.aplicaIva ?? false);
    _activoNotifier     = ValueNotifier<bool>(p?.activo ?? true);

    if (p != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _preseleccionarFk(p));
    }
  }

  void _preseleccionarFk(Producto p) {
    if (!mounted) return;
    final categorias = ref.read(categoriasProvider).value?.categorias ?? [];
    final unidades = ref.read(unidadesMedidaProvider).value?.unidades ?? [];

    if (p.categoriaId != null) {
      _categoriaNotifier.value =
          categorias.where((c) => c.id == p.categoriaId).firstOrNull;
    }
    if (p.proveedorId != null) {
      _proveedorNotifier.value = widget.proveedoresVm.proveedores
          .where((pr) => pr.id == p.proveedorId)
          .firstOrNull;
    }
    if (p.unidadMedidaId != null) {
      _unidadNotifier.value =
          unidades.where((u) => u.id == p.unidadMedidaId).firstOrNull;
    }
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
    _categoriaNotifier.dispose();
    _proveedorNotifier.dispose();
    _unidadNotifier.dispose();
    _imagenRutaNotifier.dispose();
    _aplicaIvaNotifier.dispose();
    _activoNotifier.dispose();
    super.dispose();
  }

  // Genera y asigna el SKU cuando se selecciona una categoría (solo en creación)
  void _onCategoriaChanged(Categoria? cat) {
    if (cat == null) return;
    final sku = ref.read(productosProvider.notifier).generarSku(cat.nombre);
    _skuCtrl.text = sku;
  }

  // Guardar

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final precioCompra =
        double.tryParse(_precioCompraCtrl.text.replaceAll(',', '')) ?? 0;
    final precioVenta =
        double.tryParse(_precioVentaCtrl.text.replaceAll(',', '')) ?? 0;
    final precioTaller = _precioTallerCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_precioTallerCtrl.text.replaceAll(',', ''));
    final stock =
        double.tryParse(_stockCtrl.text.replaceAll(',', '')) ?? 0;
    final stockMinimo =
        double.tryParse(_stockMinimoCtrl.text.replaceAll(',', '')) ?? 0;

    final categoria = _categoriaNotifier.value;
    final proveedor = _proveedorNotifier.value;
    final unidad    = _unidadNotifier.value;

    final producto = Producto(
      id: widget.esEdicion ? widget.productoAEditar!.id : null,
      sku:    _skuCtrl.text.trim(),
      nombre: _nombreCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim().isEmpty
          ? null
          : _descripcionCtrl.text.trim(),
      categoriaId:       categoria?.id,
      categoriaNombre:   categoria?.nombre,
      unidadMedidaId:    unidad?.id,
      unidadMedidaNombre: unidad?.nombre,
      proveedorId:        proveedor?.id,
      proveedorNombre:    proveedor?.nombre,
      precioCompra:       precioCompra,
      precioVenta:        precioVenta,
      precioVentaTaller:  precioTaller,
      stockActual:        stock,
      stockMinimo:        stockMinimo,
      ubicacionBodega: _ubicacionCtrl.text.trim().isEmpty
          ? null
          : _ubicacionCtrl.text.trim(),
      imagenUrl: _imagenRutaNotifier.value,
      aplicaIva: _aplicaIvaNotifier.value,
      activo:    _activoNotifier.value,
    );

    final error = widget.esEdicion
        ? await ref.read(productosProvider.notifier).actualizar(producto)
        : await ref.read(productosProvider.notifier).crear(producto);

    if (!mounted) return;

    if (error != null) {
      SnackBarMensaje.error(context, error);
      setState(() => _guardando = false);
    } else {
      Navigator.of(context).pop();
      SnackBarMensaje.success(
        context,
        widget.esEdicion
            ? 'Producto actualizado correctamente'
            : 'Producto creado correctamente',
      );
    }
  }

  // Build

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 580,
        height: MediaQuery.of(context).size.height * 0.90,
        child: Column(
          children: [
            _Encabezado(
              titulo: widget.esEdicion ? 'Editar Producto' : 'Nuevo Producto',
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SeccionBasica(
                        skuCtrl:         _skuCtrl,
                        nombreCtrl:      _nombreCtrl,
                        descripcionCtrl: _descripcionCtrl,
                      ),
                      const SizedBox(height: 20),
                      SeccionClasificacion(
                        categoriaNotifier:   _categoriaNotifier,
                        proveedorNotifier:   _proveedorNotifier,
                        unidadNotifier:      _unidadNotifier,
                        ubicacionCtrl:       _ubicacionCtrl,
                        imagenRutaNotifier:  _imagenRutaNotifier,
                        onCategoriaChanged:  _onCategoriaChanged,
                      ),
                      const SizedBox(height: 20),
                      SeccionPrecios(
                        precioCompraCtrl: _precioCompraCtrl,
                        precioVentaCtrl:  _precioVentaCtrl,
                        precioTallerCtrl: _precioTallerCtrl,
                        aplicaIvaNotifier: _aplicaIvaNotifier,
                      ),
                      const SizedBox(height: 20),
                      SeccionInventario(
                        stockCtrl:       _stockCtrl,
                        stockMinimoCtrl: _stockMinimoCtrl,
                        activoNotifier:  _activoNotifier,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
            _BotonesDialogo(
              esEdicion: widget.esEdicion,
              guardando: _guardando,
              onGuardar: _guardar,
            ),
          ],
        ),
      ),
    );
  }
}

// Sub-widgets estáticos

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.titulo});
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: ColoresApp.textDark,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: ColoresApp.textMedium),
            style: IconButton.styleFrom(
              backgroundColor: ColoresApp.bgContent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonesDialogo extends StatelessWidget {
  const _BotonesDialogo({
    required this.esEdicion,
    required this.guardando,
    required this.onGuardar,
  });

  final bool esEdicion;
  final bool guardando;
  final VoidCallback onGuardar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: ColoresApp.textMedium,
                side: const BorderSide(color: ColoresApp.border),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: guardando ? null : onGuardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: ColoresApp.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(esEdicion ? 'Guardar cambios' : 'Crear producto'),
            ),
          ),
        ],
      ),
    );
  }
}
