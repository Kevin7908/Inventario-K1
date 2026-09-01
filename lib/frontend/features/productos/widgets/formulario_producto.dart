import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/categorias/modelo/categoria.dart';
import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../../backend/features/proveedores/modelo/proveedor.dart';
import '../../../../backend/features/unidades_medida/modelo/unidad_medida.dart';
import '../../../../core/iva_app.dart';
import '../../../../core/resultado.dart';
import '../../../../core/validaciones.dart';
import '../../../share/share.dart';
import '../../categorias/provider/categorias_provider.dart';
import '../../proveedores/provider/proveedores_provider.dart';
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
/// - [alTerminar]: se llama tras guardar con éxito, para que el contenedor
///   cierre el diálogo o vuelva a la lista.
/// - [alCancelar]: se llama al presionar "Cancelar".
class FormularioProducto extends ConsumerStatefulWidget {
  const FormularioProducto({
    super.key,
    this.productoAEditar,
    required this.alTerminar,
    required this.alCancelar,
  });

  final Producto? productoAEditar;
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
  late final TextEditingController _codigoBarrasCtrl;
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

    String texto(num? v) => v == null ? '' : v.toStringAsFixed(0);

    _skuCtrl = TextEditingController(text: p?.sku ?? '');
    _codigoBarrasCtrl = TextEditingController(text: p?.codigoBarras ?? '');
    _nombreCtrl = TextEditingController(text: p?.nombre ?? '');
    _descripcionCtrl = TextEditingController(text: p?.descripcion ?? '');
    _precioCompraCtrl = TextEditingController(text: texto(p?.precioCompra));
    _precioVentaCtrl = TextEditingController(text: texto(p?.precioVenta));
    _precioTallerCtrl = TextEditingController(text: texto(p?.precioVentaTaller));
    _stockCtrl = TextEditingController(text: texto(p?.stockActual) );
    _stockMinimoCtrl = TextEditingController(text: texto(p?.stockMinimo));
    _ubicacionCtrl = TextEditingController(text: p?.ubicacionBodega ?? '');

    _imagenRuta = p?.imagenUrl;
    _aplicaIva = p?.aplicaIva ?? false;
    _activo = p?.activo ?? true;

    if (p != null) {
      // Las listas de FK viven en providers que no están resueltos durante
      // initState. Se preseleccionan tras el primer frame, cuando el `build`
      // ya suscribió los tres providers y sus futuros pueden completarse.
      WidgetsBinding.instance.addPostFrameCallback((_) => _preseleccionarFk(p));
    }
  }

  /// Marca en los selectores la categoría, unidad y proveedor que el producto
  /// ya tiene.
  ///
  /// **Espera** a que cada catálogo llegue en vez de leer su valor actual: al
  /// abrir el formulario en frío —el diálogo que abren cotizaciones, facturas
  /// u órdenes— los streams todavía no han emitido, y una lectura seca dejaba
  /// los tres campos en "Sin …" aunque el producto los tuviera asignados.
  ///
  /// Los tres van por su cuenta, no en un `await` encadenado: si un catálogo
  /// tarda o falla, los otros dos igual quedan marcados.
  void _preseleccionarFk(Producto p) {
    unawaited(_marcar(
      ref.read(catalogoCategoriasProvider.future),
      (lista) =>
          _categoria = lista.where((c) => c.id == p.categoriaId).firstOrNull,
    ));
    unawaited(_marcar(
      ref.read(unidadesMedidaProvider.future),
      (estado) => _unidad =
          estado.unidades.where((u) => u.id == p.unidadMedidaId).firstOrNull,
    ));
    unawaited(_marcar(
      ref.read(catalogoProveedoresProvider.future),
      (lista) =>
          _proveedor = lista.where((pr) => pr.id == p.proveedorId).firstOrNull,
    ));
  }

  /// Espera a [futuro] y aplica [asignar] dentro de un `setState`.
  Future<void> _marcar<T>(
    Future<T> futuro,
    void Function(T datos) asignar,
  ) async {
    final datos = await futuro;
    if (!mounted) return;
    setState(() => asignar(datos));
  }

  @override
  void dispose() {
    _skuCtrl.dispose();
    _codigoBarrasCtrl.dispose();
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

  /// Al elegir categoría se enseña el SKU que le tocaría.
  ///
  /// Es una **previsualización**: el definitivo lo asigna el repositorio
  /// dentro de la transacción del alta, así que cambiar de categoría diez
  /// veces no quema diez códigos. En edición no se toca: el SKU ya está
  /// impreso en la estantería.
  Future<void> _alCambiarCategoria(Categoria? categoria) async {
    setState(() => _categoria = categoria);
    if (widget.esEdicion) return;

    final sku = await ref
        .read(repositorioProductosProvider)
        .previsualizarSku(categoria?.id);
    if (!mounted) return;
    _skuCtrl.text = sku;
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
      double.tryParse(ctrl.text.replaceAll(',', '.').trim()) ?? 0;

  /// Los importes del catálogo son pesos enteros (ver `TablaProducto`). Los
  /// campos traen los puntos de miles del formateador (`45.000`), así que se
  /// limpian antes de convertir: lo que se guarda es 45000, no un `double`
  /// que arrastre medio peso hasta la factura.
  int _aPesos(TextEditingController ctrl) =>
      int.tryParse(normalizarDigitos(ctrl.text)) ?? 0;

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final descripcion = _descripcionCtrl.text.trim();
    final ubicacion = _ubicacionCtrl.text.trim();
    final precioTaller = _precioTallerCtrl.text.trim().isEmpty
        ? null
        : _aPesos(_precioTallerCtrl);

    final producto = Producto(
      id: widget.productoAEditar?.id,
      // Al crear se manda **vacío** a propósito: lo que se ve en el campo es
      // una previsualización, y el número bueno lo toma el repositorio de la
      // serie, dentro de su transacción. Mandar el previsualizado haría que
      // dos altas seguidas de la misma categoría compartieran SKU.
      sku: widget.esEdicion ? _skuCtrl.text.trim() : '',
      // Vacío es «sin código», no la cadena vacía: el `UNIQUE` de la columna
      // admite varios NULL, pero solo un ''. El repositorio lo normaliza.
      codigoBarras: _codigoBarrasCtrl.text.trim().isEmpty
          ? null
          : _codigoBarrasCtrl.text.trim(),
      nombre: _nombreCtrl.text.trim(),
      descripcion: descripcion.isEmpty ? null : descripcion,
      categoriaId: _categoria?.id,
      categoriaNombre: _categoria?.nombre,
      unidadMedidaId: _unidad?.id,
      unidadMedidaNombre: _unidad?.nombre,
      proveedorId: _proveedor?.id,
      proveedorNombre: _proveedor?.nombre,
      precioCompra: _aPesos(_precioCompraCtrl),
      precioVenta: _aPesos(_precioVentaCtrl),
      precioVentaTaller: precioTaller,
      stockActual: _aDouble(_stockCtrl),
      stockMinimo: _aDouble(_stockMinimoCtrl),
      ubicacionBodega: ubicacion.isEmpty ? null : ubicacion,
      imagenUrl: _imagenRuta,
      aplicaIva: _aplicaIva,
      activo: _activo,
    );

    final notifier = ref.read(productosProvider.notifier);
    final resultado = widget.esEdicion
        ? await notifier.actualizar(producto)
        : await notifier.crear(producto);

    if (!mounted) return;

    if (resultado case Fallo(:final mensaje)) {
      _mostrarMensaje(mensaje, esError: true);
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
        ref.watch(catalogoCategoriasProvider).value ?? const [];
    final unidades =
        ref.watch(unidadesMedidaProvider).value?.unidades ?? const [];

    return PanelSeccion(
      titulo: 'Información general',
      icono: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilaCampos(
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
              // Solo lectura: lo arma la app con el prefijo de la categoría.
              // Tecleado a mano volvían a aparecer los duplicados y los
              // formatos de cada quien.
              CampoTexto(
                etiqueta: 'Código / SKU',
                controlador: _skuCtrl,
                placeholder: 'Se genera al elegir la categoría',
                monoespaciado: true,
                soloLectura: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // El del empaque, aparte del SKU: aquel lo arma la app, este viene
          // impreso y sirve para buscar pasando el lector en el mostrador.
          CampoTexto(
            etiqueta: 'Código de barras (opcional)',
            controlador: _codigoBarrasCtrl,
            placeholder: 'Pasa el lector o tecléalo',
            monoespaciado: true,
          ),
          const SizedBox(height: 16),
          FilaCampos(
            hijos: [
              CampoBusqueda<Categoria>(
                etiqueta: 'Categoría',
                valor: _categoria,
                opciones: categorias,
                constructorEtiqueta: (c) => c.nombre,
                constructorDetalle: (c) => c.descripcion,
                placeholder: 'Sin categoría',
                placeholderBusqueda: 'Buscar categoría…',
                alCambiar: _alCambiarCategoria,
              ),
              CampoBusqueda<UnidadMedida>(
                etiqueta: 'Unidad de medida',
                valor: _unidad,
                opciones: unidades,
                constructorEtiqueta: (u) => u.nombre,
                constructorDetalle: (u) => u.abreviatura,
                placeholder: 'Sin unidad',
                placeholderBusqueda: 'Buscar unidad…',
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
    // Solo los activos: un proveedor dado de baja sigue asociado a sus
    // productos viejos, pero no debería ofrecerse para nuevos.
    final proveedores = [
      for (final p in ref.watch(catalogoProveedoresProvider).value ?? const [])
        if (p.activo || p.id == _proveedor?.id) p,
    ];

    return PanelSeccion(
      titulo: 'Precio e inventario',
      icono: Icons.sell_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilaCampos(
            hijos: [
              CampoTexto(
                etiqueta: 'Precio de venta *',
                controlador: _precioVentaCtrl,
                placeholder: '0',
                comoPrecio: true,
                validador: (v) {
                  final error = validarImporte(v);
                  if (error != null) return error;
                  final valor = int.tryParse(normalizarDigitos(v ?? '')) ?? 0;
                  return valor <= 0 ? 'Debe ser mayor a 0.' : null;
                },
              ),
              CampoTexto(
                etiqueta: 'Stock actual',
                controlador: _stockCtrl,
                placeholder: '0',
                validador: (v) => validarCantidad(v, obligatorio: false),
              ),
              CampoTexto(
                etiqueta: 'Stock mínimo',
                controlador: _stockMinimoCtrl,
                placeholder: '0',
                validador: (v) => validarCantidad(v, obligatorio: false),
              ),
              CampoTexto(
                etiqueta: 'Ubicación',
                controlador: _ubicacionCtrl,
                placeholder: 'Bodega A-12',
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilaCampos(
            hijos: [
              CampoTexto(
                etiqueta: 'Precio de compra',
                controlador: _precioCompraCtrl,
                placeholder: '0',
                comoPrecio: true,
                validador: (v) => validarImporte(v, obligatorio: false),
              ),
              CampoTexto(
                etiqueta: 'Precio taller',
                controlador: _precioTallerCtrl,
                placeholder: 'Opcional',
                comoPrecio: true,
                validador: (v) => validarImporte(v, obligatorio: false),
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
                child: InterruptorCampo(
                  etiqueta: 'Aplica IVA',
                  detalle: _aplicaIva
                      ? 'El precio ya incluye ${(kIva * 100).toStringAsFixed(0)}% de IVA'
                      : 'Precio sin IVA',
                  valor: _aplicaIva,
                  alCambiar: (v) => setState(() => _aplicaIva = v),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InterruptorCampo(
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

