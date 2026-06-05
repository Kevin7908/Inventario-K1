import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/frontend/features/productos/widgets/tarjeta_producto_widget.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/widgets/input/barra_busqueda_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/output/estado_vacio_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/paginacion_widget.dart';

import '../../provider/reservas_provider.dart';
import '../../reserva_editor/provider/reserva_editor_provider.dart';

class GrillaProductosReservaWidget extends ConsumerWidget {
  const GrillaProductosReservaWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productos = ref.watch(productosParaReservaProvider).value ?? const [];
    final estado = ref.watch(reservaEditorProvider);
    final notifier = ref.read(reservaEditorProvider.notifier);

    final filtrados = estado.filtrarProductos(productos);
    final pagina = estado.paginaDeProductos(filtrados);
    final totalPaginas = estado.totalPaginasProductos(filtrados);

    // Ajusta el stock visible descontando lo que ya está en el carrito
    final paginaAjustada = pagina.map((p) {
      if (p.id == null) return p;
      final enCarrito = estado.cantidadEnCarrito(p.id!);
      if (enCarrito <= 0) return p;
      return p.copyWith(
        stockActual: (p.stockActual - enCarrito).clamp(0, p.stockActual),
      );
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CabeceraGrilla(
            busqueda: estado.busquedaProductos,
            onBuscar: notifier.buscarProductos,
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                if (pagina.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: EstadoVacioWidget(
                      icono: Icons.inventory_2_outlined,
                      textoSinDatos: 'Sin productos',
                      textoSinResultados: 'No hay productos que coincidan.',
                      textoCTA: '',
                      hayFiltro: estado.busquedaProductos.isNotEmpty,
                    ),
                  )
                else
                  _GrillaCards(
                    productos: paginaAjustada,
                    productosOriginales: pagina,
                    cantidadesEnCarrito: {
                      for (final p in pagina)
                        if (p.id != null) p.id!: estado.cantidadEnCarrito(p.id!)
                    },
                    onTap: (p, pOriginal) => _mostrarDialogoCantidad(
                      context,
                      ref,
                      p,
                      pOriginal,
                      estado,
                      notifier,
                    ),
                    onRemove: notifier.toggleProducto,
                  ),
                if (totalPaginas > 1) ...[
                  const SizedBox(height: 10),
                  PaginacionWidget(
                    paginaActual: estado.paginaProductos,
                    totalPaginas: totalPaginas,
                    totalItems: filtrados.length,
                    itemsPorPagina: ReservaEditorState.productosPorPagina,
                    alCambiarPagina: notifier.cambiarPaginaProductos,
                    labelEntidad: 'productos',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoCantidad(
    BuildContext context,
    WidgetRef ref,
    Producto pAjustado,
    Producto pOriginal,
    ReservaEditorState estado,
    ReservaEditorNotifier notifier,
  ) async {
    final enCarrito = pOriginal.id != null
        ? estado.cantidadEnCarrito(pOriginal.id!)
        : 0;
    final stockDisponible = pAjustado.stockActual;

    // Sin stock y no está en carrito → nada que hacer
    if (stockDisponible <= 0 && enCarrito == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este producto no tiene stock disponible.'),
          backgroundColor: ColoresApp.statusDebt,
        ),
      );
      return;
    }

    final cantidad = await showDialog<double>(
      context: context,
      builder: (_) => _DialogoCantidad(
        producto: pOriginal,
        stockDisponible: pOriginal.stockActual.toInt(),
        cantidadActual: enCarrito.toDouble(),
      ),
    );

    if (cantidad == null) return;
    if (cantidad <= 0) {
      notifier.toggleProducto(pOriginal); // quitar del carrito
    } else {
      notifier.agregarProductoConCantidad(pOriginal, cantidad);
    }
  }
}

// ── Cabecera ──────────────────────────────────────────────────────────────────

class _CabeceraGrilla extends StatelessWidget {
  const _CabeceraGrilla({
    required this.busqueda,
    required this.onBuscar,
  });

  final String busqueda;
  final ValueChanged<String> onBuscar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
        border: Border(bottom: BorderSide(color: ColoresApp.border)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'PRODUCTOS A RESERVAR',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: ColoresApp.primary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 300,
            child: BarraBusquedaWidget(
              placeholder: 'Buscar producto…',
              alCambiar: onBuscar,
              debounceMs: 280,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grilla de tarjetas ────────────────────────────────────────────────────────

class _GrillaCards extends StatelessWidget {
  const _GrillaCards({
    required this.productos,
    required this.productosOriginales,
    required this.cantidadesEnCarrito,
    required this.onTap,
    required this.onRemove,
  });

  final List<Producto> productos;
  final List<Producto> productosOriginales;
  final Map<int, int> cantidadesEnCarrito;
  final void Function(Producto ajustado, Producto original) onTap;
  final ValueChanged<Producto> onRemove;

  static const double _maxAncho = 200.0;
  static const double _espaciado = 10.0;
  static const double _altura = 300.0;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _maxAncho,
        crossAxisSpacing: _espaciado,
        mainAxisSpacing: _espaciado,
        mainAxisExtent: _altura,
      ),
      itemCount: productos.length,
      itemBuilder: (_, i) {
        final p = productos[i];
        final pOrig = productosOriginales[i];
        final enCarrito =
            (pOrig.id != null && (cantidadesEnCarrito[pOrig.id!] ?? 0) > 0);

        return Stack(
          children: [
            TarjetaProductoWidget(
              key: ValueKey(p.id),
              producto: p,
              alTap: () => enCarrito
                  ? onTap(p, pOrig)
                  : onTap(p, pOrig),
            ),
            if (enCarrito)
              Positioned(
                top: 8,
                left: 8,
                child: _BadgeEnCarrito(
                  cantidad: cantidadesEnCarrito[pOrig.id!]!,
                  onRemove: () => onRemove(pOrig),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BadgeEnCarrito extends StatelessWidget {
  const _BadgeEnCarrito({required this.cantidad, required this.onRemove});

  final int cantidad;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: ColoresApp.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '✓ $cantidad',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.close_rounded, size: 10, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ── Diálogo de cantidad ───────────────────────────────────────────────────────

class _DialogoCantidad extends StatefulWidget {
  const _DialogoCantidad({
    required this.producto,
    required this.stockDisponible,
    required this.cantidadActual,
  });

  final Producto producto;
  final int stockDisponible;
  final double cantidadActual;

  @override
  State<_DialogoCantidad> createState() => _DialogoCantidadState();
}

class _DialogoCantidadState extends State<_DialogoCantidad> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final inicial = widget.cantidadActual > 0
        ? widget.cantidadActual.toInt().toString()
        : '1';
    _ctrl = TextEditingController(text: inicial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int get _stockMax => widget.stockDisponible;

  void _validar(String v) {
    final n = int.tryParse(v);
    setState(() {
      if (v.isEmpty || n == null) {
        _error = 'Ingresa una cantidad válida.';
      } else if (n <= 0) {
        _error = 'La cantidad debe ser mayor a 0.';
      } else if (n > _stockMax) {
        _error = 'Solo hay $_stockMax unidad${_stockMax == 1 ? '' : 'es'} disponibles.';
      } else {
        _error = null;
      }
    });
  }

  void _confirmar() {
    _validar(_ctrl.text);
    if (_error != null) return;
    final n = int.tryParse(_ctrl.text);
    if (n == null || n <= 0) return;
    Navigator.of(context).pop(n.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    final sinStock = _stockMax <= 0 && widget.cantidadActual == 0;

    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.nombre,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ColoresApp.textDark,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'SKU: ${p.sku}  ·  Stock disponible: $_stockMax',
                style: const TextStyle(
                  fontSize: 11,
                  color: ColoresApp.textLight,
                ),
              ),
              const SizedBox(height: 16),
              if (sinStock)
                const _MensajeSinStock()
              else ...[
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: _validar,
                  onSubmitted: (_) => _confirmar(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: ColoresApp.textDark,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    labelText: 'Cantidad',
                    labelStyle:
                        const TextStyle(color: ColoresApp.textMedium),
                    filled: true,
                    fillColor: ColoresApp.bgContent,
                    errorText: _error,
                    suffixText: p.unidadMedidaNombre ?? 'uds',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: ColoresApp.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: ColoresApp.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: ColoresApp.primary, width: 1.5)),
                    errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: ColoresApp.statusDebt)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _confirmar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColoresApp.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                      child: const Text('Agregar',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MensajeSinStock extends StatelessWidget {
  const _MensajeSinStock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.inventory_2_outlined,
            size: 36, color: ColoresApp.textLight),
        const SizedBox(height: 8),
        const Text(
          'Sin stock disponible',
          style: TextStyle(fontSize: 13, color: ColoresApp.textMedium),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ),
      ],
    );
  }
}
