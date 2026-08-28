import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../../backend/share/dominio/sesion_actual.dart';
import '../../../../core/formato.dart';
import '../../../share/share.dart';
import '../../productos/provider/productos_provider.dart';
import '../provider/inventario_providers.dart';

/// Da entrada a la mercancía que llega del proveedor.
///
/// Es la única forma de escribir `ENTRADA_COMPRA`, y va por
/// `RepositorioInventario.registrarEntradaCompra`: el stock nunca se toca con
/// un `UPDATE` suelto.
///
/// Parámetros:
/// - [producto]: si viene, ya está elegido y no se puede cambiar —es como se
///   abre desde la ficha—. Con `null` aparece el buscador del catálogo.
///
/// Ejemplo:
/// ```dart
/// await DialogoEntradaCompra.mostrar(context, producto: producto);
/// ```
class DialogoEntradaCompra extends ConsumerStatefulWidget {
  const DialogoEntradaCompra({super.key, this.producto});

  final Producto? producto;

  static Future<bool?> mostrar(BuildContext context, {Producto? producto}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => DialogoEntradaCompra(producto: producto),
    );
  }

  @override
  ConsumerState<DialogoEntradaCompra> createState() =>
      _DialogoEntradaCompraState();
}

class _DialogoEntradaCompraState extends ConsumerState<DialogoEntradaCompra> {
  final _notas = TextEditingController();
  late Producto? _elegido = widget.producto;
  double _cantidad = 1;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final producto = _elegido;
    if (producto?.id == null) {
      setState(() => _error = 'Elige el producto que llegó.');
      return;
    }
    if (_cantidad <= 0) {
      setState(() => _error = 'La cantidad tiene que ser mayor que cero.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await ref.read(repositorioInventarioProvider).registrarEntradaCompra(
            productoId: producto!.id!,
            cantidad: _cantidad,
            notas: _notas.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      MensajeApp.exito(
        context,
        'Entraron ${formatearCantidad(_cantidad)} de ${producto.nombre}',
      );
    } on PermisoDenegado catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = e.mensaje;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = 'No se pudo registrar la entrada: $e';
      });
    }
  }

  void _cerrar() => Navigator.of(context).pop(false);

  @override
  Widget build(BuildContext context) {
    final producto = _elegido;

    return AtajosFormulario(
      alGuardar: _guardando ? null : _guardar,
      alCancelar: _cerrar,
      child: Dialog(
        backgroundColor: ColoresApp.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Dar entrada a mercancía',
                    style: TipografiaApp.heading3),
                const SizedBox(height: 4),
                Text(
                  'Lo que llega del proveedor. Queda como entrada de compra en '
                  'el libro de movimientos.',
                  style: TipografiaApp.caption
                      .copyWith(color: ColoresApp.textMuted),
                ),
                const SizedBox(height: 20),
                if (widget.producto == null)
                  _SelectorProducto(
                    valor: producto,
                    alCambiar: (elegido) => setState(() {
                      _elegido = elegido;
                      _error = null;
                    }),
                  )
                else
                  _ProductoFijo(producto: producto!),
                const SizedBox(height: 16),
                const Text('Cuánto llegó', style: TipografiaApp.etiquetaCampo),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ControlCantidad(
                    cantidad: _cantidad,
                    alCambiar: (valor) => setState(() => _cantidad = valor),
                  ),
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  etiqueta: 'Nota (opcional)',
                  controlador: _notas,
                  placeholder: 'Remisión, factura del proveedor…',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  AvisoEnLinea(mensaje: _error!, tono: TonoAviso.error),
                ],
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    BotonSecundario(
                      etiqueta: 'Cancelar',
                      alPresionar: _guardando ? null : _cerrar,
                    ),
                    const SizedBox(width: 12),
                    BotonPrimario(
                      etiqueta: _guardando ? 'Guardando…' : 'Dar entrada',
                      icono: Icons.add_rounded,
                      alPresionar: _guardando ? null : _guardar,
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

/// Marca el producto ya elegido cuando el diálogo se abre desde su ficha.
class _ProductoFijo extends StatelessWidget {
  const _ProductoFijo({required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ColoresApp.bgInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresApp.borderInput),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 18, color: ColoresApp.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  producto.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TipografiaApp.cuerpoMedium,
                ),
                Text(
                  '${producto.sku} · hay '
                  '${formatearCantidad(producto.stockActual)}',
                  style: TipografiaApp.caption
                      .copyWith(color: ColoresApp.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// El buscador del catálogo, cuando el diálogo se abre desde el kardex y
/// todavía no se sabe qué producto llegó.
///
/// **Pide el catálogo completo a propósito** (`CLAUDE.md` §7): un selector con
/// buscador necesita la lista entera para poder filtrarla mientras se teclea,
/// y no hay página que valga cuando el usuario escribe tres letras del nombre.
/// Es un `ConsumerWidget` aparte para que tocar la cantidad o la nota no
/// vuelva a leerlo.
class _SelectorProducto extends ConsumerWidget {
  const _SelectorProducto({required this.valor, required this.alCambiar});

  final Producto? valor;
  final ValueChanged<Producto?> alCambiar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo =
        ref.watch(catalogoCompletoProvider).value ?? const <Producto>[];

    return CampoBusqueda<Producto>(
      etiqueta: 'Producto',
      valor: valor,
      opciones: catalogo,
      constructorEtiqueta: (p) => p.nombre,
      constructorDetalle: (p) =>
          '${p.sku} · hay ${formatearCantidad(p.stockActual)}',
      placeholder: 'Buscar el producto que llegó…',
      placeholderBusqueda: 'Nombre o SKU…',
      alCambiar: alCambiar,
    );
  }
}
