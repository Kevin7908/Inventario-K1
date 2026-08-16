import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../../backend/features/productos/modelo/producto.dart';
import '../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../../../../core/currency_ext.dart';
import '../../../../../core/iva_app.dart';
import '../widgets/dialogo_cobro_pos.dart';
import '../../../../features/clientes/provider/cliente_provider.dart';
import '../../../../features/productos/widgets/tarjeta_producto_widget.dart';
import '../../../../share/temas/colores_app.dart';
import '../../../../share/widgets/input/app_searc_widget.dart';
import '../../../../share/widgets/input/barra_busqueda_widget.dart';
import '../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../provider/pos_providers.dart';
import '../provider/pos_state.dart';

const _kAccent = ColoresApp.primary;

class VentaRapidaVista extends StatelessWidget {
  const VentaRapidaVista({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _CatalogPanel()),
        SizedBox(
          width: 1,
          child: ColoredBox(color: ColoresApp.border, child: SizedBox.expand()),
        ),
        SizedBox(width: 360, child: _CartPanel()),
      ],
    );
  }
}

// ── Panel catálogo ─────────────────────────────────────────────────────────────

class _CatalogPanel extends ConsumerWidget {
  const _CatalogPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo   = ref.watch(posCatalogoProvider);
    final categorias = ref.watch(posCategoriasProvider);
    final categoriaActual = ref.watch(posProvider).categoriaFiltro;

    return Container(
      color: ColoresApp.bgContent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Búsqueda y categorías ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: BarraBusquedaWidget(
              placeholder: 'Buscar producto, SKU…',
              debounceMs: 280,
              alCambiar: (q) => ref.read(posProvider.notifier).buscar(q),
            ),
          ),
          if (categorias.isNotEmpty)
            _CategoriasChips(
              categorias:    categorias,
              categoriaActual: categoriaActual,
              onFiltrar: (c) =>
                  ref.read(posProvider.notifier).filtrarCategoria(c),
            ),
          const Divider(height: 1, color: ColoresApp.border),
          // ── Grid de productos ─────────────────────────────────────────
          Expanded(
            child: catalogo.isEmpty
                ? const _CatalogEmpty()
                : _ProductGrid(catalogo: catalogo),
          ),
        ],
      ),
    );
  }
}

class _CategoriasChips extends StatelessWidget {
  const _CategoriasChips({
    required this.categorias,
    required this.categoriaActual,
    required this.onFiltrar,
  });

  final List<String>          categorias;
  final String?               categoriaActual;
  final ValueChanged<String?> onFiltrar;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _CatChip(
            label: 'Todos',
            seleccionado: categoriaActual == null,
            onTap: () => onFiltrar(null),
          ),
          ...categorias.map(
            (c) => Padding(
              padding: const EdgeInsets.only(left: 5),
              child: _CatChip(
                label: c,
                seleccionado: categoriaActual == c,
                onTap: () =>
                    onFiltrar(categoriaActual == c ? null : c),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip({
    required this.label,
    required this.seleccionado,
    required this.onTap,
  });

  final String       label;
  final bool         seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: seleccionado ? _kAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: seleccionado ? _kAccent : ColoresApp.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: seleccionado ? Colors.white : ColoresApp.textMedium,
          ),
        ),
      ),
    );
  }
}

class _ProductGrid extends ConsumerWidget {
  const _ProductGrid({required this.catalogo});
  final List<Producto> catalogo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250,
        crossAxisSpacing:   12,
        mainAxisSpacing:    12,
        mainAxisExtent:     310,
      ),
      itemCount: catalogo.length,
      itemBuilder: (_, i) {
        final p = catalogo[i];
        return RepaintBoundary(
          child: TarjetaProductoWidget(
            key:   ValueKey(p.id),
            producto: p,
            alTap: () => ref.read(posProvider.notifier).agregar(p),
          ),
        );
      },
    );
  }
}

class _CatalogEmpty extends StatelessWidget {
  const _CatalogEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: ColoresApp.textLight),
          SizedBox(height: 10),
          Text(
            'Sin productos',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ColoresApp.textMedium),
          ),
          SizedBox(height: 4),
          Text(
            'Ajusta el filtro o el texto de búsqueda.',
            style: TextStyle(fontSize: 12, color: ColoresApp.textLight),
          ),
        ],
      ),
    );
  }
}

// ── Panel carrito ─────────────────────────────────────────────────────────────

class _CartPanel extends ConsumerStatefulWidget {
  const _CartPanel();

  @override
  ConsumerState<_CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<_CartPanel> {
  late final ValueNotifier<Cliente?> _clienteNotifier;
  late final TextEditingController   _descuentoCtrl;

  @override
  void initState() {
    super.initState();
    _clienteNotifier = ValueNotifier(null);
    _clienteNotifier.addListener(_syncCliente);
    _descuentoCtrl = TextEditingController(text: '0');
  }

  void _syncCliente() {
    final c = _clienteNotifier.value;
    ref.read(posProvider.notifier).seleccionarCliente(c?.id, c?.nombreCompleto);
  }

  @override
  void dispose() {
    _clienteNotifier
      ..removeListener(_syncCliente)
      ..dispose();
    _descuentoCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    final pos      = ref.read(posProvider);
    final subtotal = pos.subtotal;
    final total    = subtotal - pos.descuento + ivaDe(subtotal);

    final resultado = await DialogoCobrarPOS.mostrar(
      context,
      total:         total,
      clienteId:     pos.clienteId,
      clienteNombre: pos.clienteNombre,
    );
    if (resultado == null || !mounted) return;

    final error = await ref.read(posProvider.notifier).procesarVenta(
      estadoPago:      resultado.estadoPago,
      totalPagado:     resultado.totalPagado,
      totalFactura:    total,
      clienteId:       pos.clienteId,
      concepto:        resultado.datosDeuda?.concepto,
      metodoPagoDeuda: resultado.datosDeuda?.metodoPago,
      fechaVencimiento: resultado.datosDeuda?.fechaVencimiento,
      notasDeuda:       resultado.datosDeuda?.notas,
    );
    if (!mounted) return;
    if (error != null) {
      SnackBarMensaje.error(context, error);
    } else {
      _clienteNotifier.value = null;
      _descuentoCtrl.text    = '0';
      SnackBarMensaje.success(context, 'Venta procesada correctamente.');
    }
  }

  void _vaciar() {
    ref.read(posProvider.notifier).vaciarCarrito();
    _descuentoCtrl.text = '0';
  }

  @override
  Widget build(BuildContext context) {
    final pos     = ref.watch(posProvider);
    final clientes = ref.watch(catalogoClientesProvider).value ?? const [];

    return Container(
      color: ColoresApp.bgCard,
      child: Column(
        children: [
          // ── Header carrito ──────────────────────────────────────────
          _CartHeader(
            total:    pos.totalUnidades,
            onVaciar: pos.items.isEmpty ? null : _vaciar,
          ),
          const Divider(height: 1, color: ColoresApp.border),
          // ── Items ────────────────────────────────────────────────────
          Expanded(
            child: pos.items.isEmpty
                ? const _CartEmpty()
                : _CartItemList(items: pos.items),
          ),
          const Divider(height: 1, color: ColoresApp.border),
          // ── Resumen + checkout ────────────────────────────────────────
          _CartFooter(
            pos:                pos,
            descuentoCtrl:      _descuentoCtrl,
            onDescuentoCambiado: (v) =>
                ref.read(posProvider.notifier).cambiarDescuento(v),
            clienteNotifier:    _clienteNotifier,
            clientes:           clientes,
            onCheckout:         _checkout,
          ),
        ],
      ),
    );
  }
}

class _CartHeader extends StatelessWidget {
  const _CartHeader({required this.total, required this.onVaciar});

  final int         total;
  final VoidCallback? onVaciar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart_outlined, size: 18, color: _kAccent),
          const SizedBox(width: 6),
          Text(
            'Carrito',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ColoresApp.textDark,
            ),
          ),
          if (total > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _kAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$total',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kAccent,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (onVaciar != null)
            TextButton(
              onPressed: onVaciar,
              style: TextButton.styleFrom(
                foregroundColor: ColoresApp.accentRed,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              child: const Text('Vaciar'),
            ),
        ],
      ),
    );
  }
}

class _CartEmpty extends StatelessWidget {
  const _CartEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 42, color: ColoresApp.textLight),
          SizedBox(height: 8),
          Text(
            'Carrito vacío',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColoresApp.textMedium),
          ),
          SizedBox(height: 3),
          Text(
            'Toca un producto para agregarlo.',
            style: TextStyle(fontSize: 11, color: ColoresApp.textLight),
          ),
        ],
      ),
    );
  }
}

class _CartItemList extends ConsumerWidget {
  const _CartItemList({required this.items});
  final List<ItemCarrito> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      itemCount: items.length,
      addAutomaticKeepAlives: false,
      itemBuilder: (_, i) {
        final item = items[i];
        return _CartItemTile(
          key:  ValueKey(item.producto.id),
          item: item,
          onAdd:    () => ref.read(posProvider.notifier).agregar(item.producto),
          onReduce: () => ref.read(posProvider.notifier).reducir(item.producto.id!),
          onRemove: () => ref.read(posProvider.notifier).eliminar(item.producto.id!),
        );
      },
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    super.key,
    required this.item,
    required this.onAdd,
    required this.onReduce,
    required this.onRemove,
  });

  final ItemCarrito  item;
  final VoidCallback onAdd;
  final VoidCallback onReduce;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ColoresApp.border)),
      ),
      child: Row(
        children: [
          // Nombre + precio
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.producto.nombre,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.textDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.producto.precioVenta.toCopString(),
                  style: const TextStyle(fontSize: 11, color: ColoresApp.textMedium),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Cantidad controles
          _QtyControl(
            cantidad: item.cantidad,
            onAdd:    onAdd,
            onReduce: onReduce,
          ),
          const SizedBox(width: 8),
          // Subtotal
          SizedBox(
            width: 70,
            child: Text(
              item.subtotal.toCopString(),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ColoresApp.textDark,
              ),
            ),
          ),
          // Eliminar
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 15),
            color: ColoresApp.textLight,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }
}

class _QtyControl extends StatelessWidget {
  const _QtyControl({
    required this.cantidad,
    required this.onAdd,
    required this.onReduce,
  });

  final int          cantidad;
  final VoidCallback onAdd;
  final VoidCallback onReduce;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: ColoresApp.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QtyBtn(icon: Icons.remove_rounded, onTap: onReduce),
          SizedBox(
            width: 28,
            child: Text(
              '$cantidad',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ColoresApp.textDark,
              ),
            ),
          ),
          _QtyBtn(icon: Icons.add_rounded, onTap: onAdd),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.onTap});
  final IconData     icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Icon(icon, size: 14, color: ColoresApp.textMedium),
      ),
    );
  }
}

// ── Footer del carrito ────────────────────────────────────────────────────────

class _CartFooter extends StatelessWidget {
  const _CartFooter({
    required this.pos,
    required this.descuentoCtrl,
    required this.onDescuentoCambiado,
    required this.clienteNotifier,
    required this.clientes,
    required this.onCheckout,
  });

  final PosState                pos;
  final TextEditingController   descuentoCtrl;
  final ValueChanged<double>    onDescuentoCambiado;
  final ValueNotifier<Cliente?> clienteNotifier;
  final List<Cliente>           clientes;
  final VoidCallback            onCheckout;

  static const _metodos = MetodoPago.values;

  @override
  Widget build(BuildContext context) {
    final subtotal  = pos.subtotal;
    final descuento = pos.descuento;
    final iva       = ivaDe(subtotal);
    final total     = subtotal - descuento + iva;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Totales
          _TotalRow(label: 'Subtotal', valor: subtotal.toCopString()),
          if (descuento > 0) ...[
            const SizedBox(height: 3),
            _TotalRow(
              label: 'Descuento',
              valor: '- ${descuento.toCopString()}',
              color: ColoresApp.accentGreen,
            ),
          ],
          const SizedBox(height: 3),
          _TotalRow(label: 'IVA (19%)', valor: iva.toCopString()),
          const Divider(height: 12, color: ColoresApp.border),
          _TotalRow(
            label: 'Total',
            valor: total.toCopString(),
            bold: true,
          ),
          const SizedBox(height: 10),
          // Descuento
          TextField(
            controller: descuentoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 13, color: ColoresApp.textDark),
            decoration: InputDecoration(
              labelText: 'Descuento (\$)',
              labelStyle: const TextStyle(fontSize: 12, color: ColoresApp.textLight),
              prefixIcon: const Icon(Icons.local_offer_outlined,
                  size: 16, color: ColoresApp.textLight),
              filled: true,
              fillColor: ColoresApp.bgContent,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: ColoresApp.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: ColoresApp.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: _kAccent, width: 1.5),
              ),
            ),
            onChanged: (v) =>
                onDescuentoCambiado(double.tryParse(v.trim()) ?? 0),
          ),
          const SizedBox(height: 10),
          // Cliente
          AppSearch<Cliente>(
            notifier:     clienteNotifier,
            items:        clientes,
            labelBuilder: (c) => c.nombreCompleto,
            hint:         'Cliente (opcional)',
            label:        'Cliente',
          ),
          const SizedBox(height: 10),
          // Método de pago
          _MetodoSelector(
            actual:  pos.metodoPago,
            metodos: _metodos,
          ),
          const SizedBox(height: 12),
          // Checkout
          ElevatedButton.icon(
            onPressed: pos.procesando || pos.items.isEmpty ? null : onCheckout,
            icon: pos.procesando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.bolt_rounded, size: 16),
            label: Text(pos.procesando ? 'Procesando…' : 'Cobrar ${total.toCopString()}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: ColoresApp.border,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.valor,
    this.bold  = false,
    this.color,
  });

  final String label;
  final String valor;
  final bool   bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final valorColor = color ?? (bold ? _kAccent : ColoresApp.textDark);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 13 : 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: bold ? ColoresApp.textDark : ColoresApp.textMedium,
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: bold ? 15 : 12,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: valorColor,
          ),
        ),
      ],
    );
  }
}

class _MetodoSelector extends ConsumerWidget {
  const _MetodoSelector({required this.actual, required this.metodos});

  final MetodoPago        actual;
  final List<MetodoPago>  metodos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: ColoresApp.border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: metodos.map((m) {
          final sel = actual == m;
          return Expanded(
            child: GestureDetector(
              onTap: () => ref.read(posProvider.notifier).cambiarMetodoPago(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? _kAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  m.etiqueta,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : ColoresApp.textMedium,
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}
