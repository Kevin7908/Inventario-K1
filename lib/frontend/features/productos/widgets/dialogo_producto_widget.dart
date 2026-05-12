import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/features/productos/widgets/componentes_formulario_widget.dart';
import 'package:provider/provider.dart';

import '../../../../backend/features/categorias/modelo/categoria.dart';
import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../../backend/features/proveedores/modelo/proveedor.dart';
import '../../../../backend/features/unidades_medida/modelo/unidad_medida.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../categorias/view_model/categorias_view_model.dart';
import '../../proveedores/view_model/proveedores_view_model.dart';
import '../../unidades_medida/view_model/unidad_medida_view_model.dart';
import '../view_model/productos_view_model.dart';

class DialogoProducto extends StatefulWidget {
  const DialogoProducto({
    super.key,
    this.productoAEditar,
    required this.viewModel,
    required this.categoriasVm,
    required this.proveedoresVm,
    required this.unidadesVm,
  });

  final Producto? productoAEditar;
  final ProductosViewModel viewModel;
  final CategoriasViewModel categoriasVm;
  final ProveedoresViewModel proveedoresVm;
  final UnidadesMedidaViewModel unidadesVm;

  bool get esEdicion => productoAEditar != null;

  static Future<void> mostrar(
    BuildContext context, {
    required ProductosViewModel viewModel,
    required CategoriasViewModel categoriasVm,
    required ProveedoresViewModel proveedoresVm,
    required UnidadesMedidaViewModel unidadesVm,
    Producto? productoAEditar,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider<ProductosViewModel>.value(value: viewModel),
          ChangeNotifierProvider<CategoriasViewModel>.value(value: categoriasVm),
          ChangeNotifierProvider<ProveedoresViewModel>.value(value: proveedoresVm),
          ChangeNotifierProvider<UnidadesMedidaViewModel>.value(value: unidadesVm),
        ],
        child: DialogoProducto(
          productoAEditar: productoAEditar,
          viewModel: viewModel,
          categoriasVm: categoriasVm,
          proveedoresVm: proveedoresVm,
          unidadesVm: unidadesVm,
        ),
      ),
    );
  }

  @override
  State<DialogoProducto> createState() => _DialogoProductoState();
}

class _DialogoProductoState extends State<DialogoProducto> {
  final _formKey = GlobalKey<FormState>();

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

  //  ValueNotifiers — renderizado granular sin setState 
  // Cada notifier actualiza solo su widget suscrito.
  // No hay setState en todo el orquestador tras initState.
  late final ValueNotifier<Categoria?> _categoriaNotifier;
  late final ValueNotifier<Proveedor?> _proveedorNotifier;
  late final ValueNotifier<UnidadMedida?> _unidadNotifier;
  late final ValueNotifier<String?> _imagenRutaNotifier;
  late final ValueNotifier<bool> _aplicaIvaNotifier;
  late final ValueNotifier<bool> _activoNotifier;

  //  initState 

  @override
  void initState() {
    super.initState();
    final p = widget.productoAEditar;

    // Controllers — un solo alloc, valores del producto o vacío/default
    _skuCtrl = TextEditingController(text: p?.sku ?? '');
    _nombreCtrl = TextEditingController(text: p?.nombre ?? '');
    _descripcionCtrl = TextEditingController(text: p?.descripcion ?? '');
    _precioCompraCtrl = TextEditingController(
      text: p?.precioCompra.toStringAsFixed(0) ?? '',
    );
    _precioVentaCtrl = TextEditingController(
      text: p?.precioVenta.toStringAsFixed(0) ?? '',
    );
    _precioTallerCtrl = TextEditingController(
      text: p?.precioVentaTaller?.toStringAsFixed(0) ?? '',
    );
    _stockCtrl = TextEditingController(
      text: p?.stockActual.toStringAsFixed(0) ?? '0',
    );
    _stockMinimoCtrl = TextEditingController(
      text: p?.stockMinimo.toStringAsFixed(0) ?? '0',
    );
    _ubicacionCtrl = TextEditingController(text: p?.ubicacionBodega ?? '');

    // Notifiers — null hasta que se resuelva FK; booleanos con defaults
    _categoriaNotifier = ValueNotifier<Categoria?>(null);
    _proveedorNotifier = ValueNotifier<Proveedor?>(null);
    _unidadNotifier = ValueNotifier<UnidadMedida?>(null);
    _imagenRutaNotifier = ValueNotifier<String?>(p?.imagenUrl);
    _aplicaIvaNotifier = ValueNotifier<bool>(p?.aplicaIva ?? true);
    _activoNotifier = ValueNotifier<bool>(p?.activo ?? true);

    // Pre-selección de FKs en modo edición
    // Se difiere al siguiente frame para que los ViewModels ya hayan
    // notificado sus listas. No usa setState — actualiza los notifiers.
    if (p != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _preseleccionarFk(p));
    }
  }

  /// Resuelve los objetos FK buscando por ID en las listas del ViewModel.
  /// Actualiza los notifiers directamente → cero reconstrucciones innecesarias.
  void _preseleccionarFk(Producto p) {
    if (!mounted) return;

    if (p.categoriaId != null) {
      _categoriaNotifier.value = widget.categoriasVm.categorias
          .where((c) => c.id == p.categoriaId)
          .firstOrNull;
    }
    if (p.proveedorId != null) {
      _proveedorNotifier.value = widget.proveedoresVm.proveedores
          .where((pr) => pr.id == p.proveedorId)
          .firstOrNull;
    }
    if (p.unidadMedidaId != null) {
      _unidadNotifier.value = widget.unidadesVm.unidades
          .where((u) => u.id == p.unidadMedidaId)
          .firstOrNull;
    }
  }

  //  dispose  limpiar Todos los recursos 

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

  // Guardar 

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<ProductosViewModel>();

    // Parseo de valores numéricos — elimina comas si el campo tiene formato
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

    // Lectura de notifiers — sin setState, sin reconstrucción
    final categoria = _categoriaNotifier.value;
    final proveedor = _proveedorNotifier.value;
    final unidad = _unidadNotifier.value;
    final imagenRuta = _imagenRutaNotifier.value;
    final aplicaIva = _aplicaIvaNotifier.value;
    final activo = _activoNotifier.value;

    final bool exito;

    if (widget.esEdicion) {
      exito = await vm.actualizarProducto(
        id: widget.productoAEditar!.id!,
        sku: _skuCtrl.text.trim(),
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim().isEmpty
            ? null
            : _descripcionCtrl.text.trim(),
        categoriaId: categoria?.id,
        categoriaNombre: categoria?.nombre,
        unidadMedidaId: unidad?.id,
        unidadMedidaNombre: unidad?.nombre,
        proveedorId: proveedor?.id,
        proveedorNombre: proveedor?.nombre,
        precioCompra: precioCompra,
        precioVenta: precioVenta,
        precioVentaTaller: precioTaller,
        stockActual: stock,
        stockMinimo: stockMinimo,
        ubicacionBodega: _ubicacionCtrl.text.trim().isEmpty
            ? null
            : _ubicacionCtrl.text.trim(),
        imagenUrl: imagenRuta,
        aplicaIva: aplicaIva,
        activo: activo,
      );
    } else {
      exito = await vm.crearProducto(
        sku: _skuCtrl.text.trim(),
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim().isEmpty
            ? null
            : _descripcionCtrl.text.trim(),
        categoriaId: categoria?.id,
        categoriaNombre: categoria?.nombre,
        unidadMedidaId: unidad?.id,
        unidadMedidaNombre: unidad?.nombre,
        proveedorId: proveedor?.id,
        proveedorNombre: proveedor?.nombre,
        precioCompra: precioCompra,
        precioVenta: precioVenta,
        precioVentaTaller: precioTaller,
        stockActual: stock,
        stockMinimo: stockMinimo,
        ubicacionBodega: _ubicacionCtrl.text.trim().isEmpty
            ? null
            : _ubicacionCtrl.text.trim(),
        imagenUrl: imagenRuta,
        aplicaIva: aplicaIva,
        activo: activo,
      );
    }

    if (!mounted) return;

    if (exito) {
      Navigator.of(context).pop();
      SnackBarMensaje.success(
        context,
        widget.esEdicion
            ? 'Producto actualizado correctamente'
            : 'Producto creado correctamente',
      );
    } else if (vm.mensajeError != null) {
      SnackBarMensaje.error(context, vm.mensajeError!);
      vm.limpiarError();
    }
  }

  //  Build 

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 580,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Encabezado estático — nunca se reconstruye 
            _Encabezado(
              titulo:
                  widget.esEdicion ? 'Editar Producto' : 'Nuevo Producto',
            ),

            // Formulario scrollable compuesto por secciones 
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Información básica
                      SeccionBasica(
                        skuCtrl: _skuCtrl,
                        nombreCtrl: _nombreCtrl,
                        descripcionCtrl: _descripcionCtrl,
                      ),

                      const SizedBox(height: 20),

                      // 2. Clasificación (categoría, proveedor, unidad, ubi, imagen)
                      SeccionClasificacion(
                        categoriaNotifier: _categoriaNotifier,
                        proveedorNotifier: _proveedorNotifier,
                        unidadNotifier: _unidadNotifier,
                        ubicacionCtrl: _ubicacionCtrl,
                        imagenRutaNotifier: _imagenRutaNotifier,
                      ),

                      const SizedBox(height: 20),

                      // 3. Precios + IVA
                      SeccionPrecios(
                        precioCompraCtrl: _precioCompraCtrl,
                        precioVentaCtrl: _precioVentaCtrl,
                        precioTallerCtrl: _precioTallerCtrl,
                        aplicaIvaNotifier: _aplicaIvaNotifier,
                      ),

                      const SizedBox(height: 20),

                      // 4. Inventario + Estado
                      SeccionInventario(
                        stockCtrl: _stockCtrl,
                        stockMinimoCtrl: _stockMinimoCtrl,
                        activoNotifier: _activoNotifier,
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),

            //  Botones fijos 
            _BotonesDialogo(
              esEdicion: widget.esEdicion,
              onGuardar: _guardar,
            ),
          ],
        ),
      ),
    );
  }
}

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
                borderRadius: BorderRadius.circular(8),
              ),
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
    required this.onGuardar,
  });

  final bool esEdicion;
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
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            // Consumer confinado — solo este botón se reconstruye al cambiar
            // estaCargando. El resto del formulario no se toca.
            child: Consumer<ProductosViewModel>(
              builder: (_, vm, __) => ElevatedButton(
                onPressed: vm.estaCargando ? null : onGuardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColoresApp.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: vm.estaCargando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(esEdicion ? 'Guardar cambios' : 'Crear producto'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}