import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/compras/modelo/compra_item.dart';
import '../../../../backend/features/compras/resultado/resultado_compra.dart';
import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../../backend/features/proveedores/modelo/proveedor.dart';
import '../../../../core/formato.dart';
import '../../../../core/resultado.dart';
import '../../../share/share.dart';
import '../../productos/provider/productos_provider.dart';
import '../../proveedores/provider/proveedores_provider.dart';
import '../provider/compras_providers.dart';
import 'linea_compra_editable.dart';

/// Registrar la remisión que llegó del proveedor: **el POS al revés**.
///
/// Se arma entera en memoria y se escribe de un golpe con
/// `RepositorioCompras.registrar`, igual que el carrito del mostrador: la
/// cabecera, las líneas y las entradas de inventario o pasan juntas o no pasa
/// ninguna.
///
/// Parámetros:
/// - [producto]: si viene, la remisión arranca con esa línea puesta. Es como
///   se abre desde la ficha de un producto.
///
/// Ejemplo:
/// ```dart
/// final registrada = await DialogoNuevaCompra.mostrar(context);
/// ```
class DialogoNuevaCompra extends ConsumerStatefulWidget {
  const DialogoNuevaCompra({super.key, this.producto});

  final Producto? producto;

  static Future<bool?> mostrar(BuildContext context, {Producto? producto}) =>
      showDialog<bool>(
        context: context,
        builder: (_) => DialogoNuevaCompra(producto: producto),
      );

  @override
  ConsumerState<DialogoNuevaCompra> createState() => _DialogoNuevaCompraState();
}

/// Una línea mientras se teclea. Guarda el producto entero para poder pintar
/// su nombre y su foto sin volver a buscarlo.
class _Linea {
  _Linea({required this.producto, required this.costo});

  final Producto producto;
  double cantidad = 1;
  int costo;

  int get subtotal => (cantidad * costo).round();
}

class _DialogoNuevaCompraState extends ConsumerState<DialogoNuevaCompra> {
  final _factura = TextEditingController();
  final _notas = TextEditingController();

  Proveedor? _proveedor;
  DateTime _fecha = DateTime.now();
  final List<_Linea> _lineas = [];
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Abierto desde la ficha de un producto, la remisión arranca con esa
    // línea puesta: es el caso de «llegaron doce de estas».
    final inicial = widget.producto;
    if (inicial != null) {
      _lineas.add(_Linea(producto: inicial, costo: inicial.precioCompra));
    }
  }

  @override
  void dispose() {
    _factura.dispose();
    _notas.dispose();
    super.dispose();
  }

  int get _total => _lineas.fold(0, (t, l) => t + l.subtotal);

  void _agregar(Producto? producto) {
    if (producto?.id == null) return;
    setState(() {
      _error = null;
      final existente = _lineas.indexWhere((l) => l.producto.id == producto!.id);
      if (existente >= 0) {
        _lineas[existente].cantidad += 1;
      } else {
        // El costo se propone con el último conocido; teclearlo es justo lo
        // que esta pantalla vino a pedir.
        _lineas.add(_Linea(producto: producto!, costo: producto.precioCompra));
      }
    });
  }

  Future<void> _registrar() async {
    final proveedor = _proveedor;
    if (proveedor?.id == null) {
      setState(() => _error = 'Elige de qué proveedor llegó la mercancía.');
      return;
    }
    if (_lineas.isEmpty) {
      setState(() => _error = 'La compra no tiene ni una línea.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final resultado = await ref.read(repositorioComprasProvider).registrar(
          proveedorId: proveedor!.id!,
          fecha: _fecha,
          numeroFactura: _factura.text,
          notas: _notas.text,
          lineas: [
            for (final l in _lineas)
              LineaCompraNueva(
                productoId: l.producto.id!,
                cantidad: l.cantidad,
                costoUnitario: l.costo,
              ),
          ],
        );

    if (!mounted) return;

    switch (resultado) {
      case CompraRegistrada(:final numero):
        Navigator.of(context).pop(true);
        MensajeApp.exito(context, 'Compra $numero registrada');
      case CompraRechazada(:final motivo, :final mensaje):
        setState(() {
          _guardando = false;
          _error = motivo == MotivoFallo.remisionDuplicada
              ? '$mensaje Revisa el número de factura.'
              : mensaje;
        });
    }
  }

  void _cerrar() => Navigator.of(context).pop(false);

  @override
  Widget build(BuildContext context) {
    return AtajosFormulario(
      alGuardar: _guardando ? null : _registrar,
      alCancelar: _cerrar,
      child: Dialog(
        backgroundColor: ColoresApp.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Registrar compra', style: TipografiaApp.heading3),
                const SizedBox(height: 4),
                Text(
                  'La remisión que llegó del proveedor. Entra al inventario y '
                  'deja el costo real de cada producto.',
                  style:
                      TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
                ),
                const SizedBox(height: 20),
                _Cabecera(
                  proveedor: _proveedor,
                  factura: _factura,
                  fecha: _fecha,
                  alCambiarProveedor: (p) => setState(() {
                    _proveedor = p;
                    _error = null;
                  }),
                  alCambiarFecha: (f) => setState(() => _fecha = f),
                ),
                const SizedBox(height: 16),
                _BuscadorProducto(alElegir: _agregar),
                const SizedBox(height: 12),
                Flexible(child: _Lineas(lineas: _lineas, alCambiar: setState)),
                const Divider(height: 24, color: ColoresApp.borderFila),
                CampoTexto(
                  etiqueta: 'Nota (opcional)',
                  controlador: _notas,
                  placeholder: 'Quién la trajo, qué faltó…',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  AvisoEnLinea(mensaje: _error!, tono: TonoAviso.error),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      'Total: ${formatearPrecio(_total)}',
                      style: TipografiaApp.heading3
                          .copyWith(color: ColoresApp.castletonGreen),
                    ),
                    const Spacer(),
                    BotonSecundario(
                      etiqueta: 'Cancelar',
                      alPresionar: _guardando ? null : _cerrar,
                    ),
                    const SizedBox(width: 12),
                    BotonPrimario(
                      etiqueta: _guardando ? 'Guardando…' : 'Registrar compra',
                      icono: Icons.local_shipping_outlined,
                      alPresionar: _guardando ? null : _registrar,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Proveedor, número de factura del proveedor y fecha de llegada.
class _Cabecera extends ConsumerWidget {
  const _Cabecera({
    required this.proveedor,
    required this.factura,
    required this.fecha,
    required this.alCambiarProveedor,
    required this.alCambiarFecha,
  });

  final Proveedor? proveedor;
  final TextEditingController factura;
  final DateTime fecha;
  final ValueChanged<Proveedor?> alCambiarProveedor;
  final ValueChanged<DateTime> alCambiarFecha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proveedores =
        ref.watch(catalogoProveedoresProvider).value ?? const <Proveedor>[];

    return FilaCampos(
      pesos: const [3, 2, 2],
      hijos: [
        CampoBusqueda<Proveedor>(
          etiqueta: 'Proveedor',
          valor: proveedor,
          opciones: proveedores.where((p) => p.activo).toList(),
          constructorEtiqueta: (p) => p.nombre,
          constructorDetalle: (p) => p.telefono ?? p.nitCedula ?? '',
          placeholder: '¿De quién llegó?',
          placeholderBusqueda: 'Nombre del proveedor…',
          alCambiar: alCambiarProveedor,
        ),
        CampoTexto(
          etiqueta: 'Factura del proveedor',
          controlador: factura,
          placeholder: 'FV-2291',
          monoespaciado: true,
        ),
        CampoFecha(
          etiqueta: 'Cuándo llegó',
          valor: fecha,
          formatear: formatearFecha,
          primeraFecha: DateTime(2020),
          ultimaFecha: DateTime.now(),
          alCambiar: alCambiarFecha,
        ),
      ],
    );
  }
}

/// El buscador del catálogo.
///
/// **Pide el catálogo completo a propósito** (`CLAUDE.md` §7): un selector con
/// buscador necesita la lista entera para filtrarla mientras se teclea. Es un
/// `ConsumerWidget` aparte para que teclear un costo no vuelva a leerlo.
class _BuscadorProducto extends ConsumerWidget {
  const _BuscadorProducto({required this.alElegir});

  final ValueChanged<Producto?> alElegir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo =
        ref.watch(catalogoCompletoProvider).value ?? const <Producto>[];

    return CampoBusqueda<Producto>(
      etiqueta: 'Agregar producto',
      valor: null,
      opciones: catalogo,
      constructorEtiqueta: (p) => p.nombre,
      constructorDetalle: (p) =>
          '${p.sku} · hay ${formatearCantidad(p.stockActual)}',
      placeholder: 'Busca lo que llegó y agrégalo a la remisión…',
      placeholderBusqueda: 'Nombre o SKU…',
      alCambiar: alElegir,
    );
  }
}

/// Las líneas tecleadas hasta ahora.
class _Lineas extends StatelessWidget {
  const _Lineas({required this.lineas, required this.alCambiar});

  final List<_Linea> lineas;

  /// El `setState` del diálogo: las líneas viven en su estado, no aquí.
  final void Function(VoidCallback) alCambiar;

  @override
  Widget build(BuildContext context) {
    if (lineas.isEmpty) {
      return const EstadoVacio(
        icono: Icons.local_shipping_outlined,
        titulo: 'Sin líneas todavía',
        pista: 'Busca arriba lo que llegó y ponle su costo.',
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: lineas.length,
      itemBuilder: (context, i) {
        final linea = lineas[i];
        return LineaCompraEditable(
          // La clave es el producto: sin ella, quitar una línea le pasaría su
          // controlador de costo a la siguiente.
          key: ValueKey(linea.producto.id),
          descripcion: linea.producto.nombre,
          sku: linea.producto.sku,
          imagen: linea.producto.imagenUrl,
          cantidad: linea.cantidad,
          costoUnitario: linea.costo,
          alCambiarCantidad: (v) => alCambiar(() => linea.cantidad = v),
          alCambiarCosto: (v) => alCambiar(() => linea.costo = v),
          alEliminar: () => alCambiar(() => lineas.removeAt(i)),
        );
      },
    );
  }
}
