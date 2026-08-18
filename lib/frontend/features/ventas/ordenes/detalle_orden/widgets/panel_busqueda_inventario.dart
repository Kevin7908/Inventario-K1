import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../backend/features/productos/modelo/producto.dart';
import '../../../../../share/formateadores/moneda_formateador.dart';
import '../../../../../share/temas/colores_app.dart';
import '../../../../../share/widgets/botones/boton_mas_widget.dart';
import '../../../../../share/widgets/output/precio_cop_widget.dart';
import '../../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../../../productos/provider/productos_provider.dart';
import '../../../../productos/widgets/dialogo_producto_widget.dart';
import '../../provider/ordenes_provider.dart';
import 'detalle_shared_widgets.dart';

class PanelBusquedaInventario extends ConsumerStatefulWidget {
  const PanelBusquedaInventario({super.key, required this.ordenId});
  final int ordenId;

  @override
  ConsumerState<PanelBusquedaInventario> createState() =>
      _PanelBusquedaInventarioState();
}

class _PanelBusquedaInventarioState
    extends ConsumerState<PanelBusquedaInventario> {
  final _searchCtrl = TextEditingController();
  int _itemsVisibles = 100;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(catalogoCompletoProvider).value ?? const [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SeccionHeader(
            titulo: 'Agregar repuesto del inventario',
            icono: Icons.add_box_outlined,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(
                        fontSize: 13.5, color: ColoresApp.textDark),
                    decoration: InputDecoration(
                      hintText: 'Buscar producto del inventario...',
                      hintStyle: const TextStyle(
                          color: ColoresApp.textLight, fontSize: 13.5),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: ColoresApp.textLight, size: 20),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _searchCtrl,
                        builder: (context, v, child) => v.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 18, color: ColoresApp.textLight),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _itemsVisibles = 100);
                                },
                              )
                            : const SizedBox.shrink(),
                      ),
                      filled: true,
                      fillColor: ColoresApp.bgContent,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
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
                    ),
                    onChanged: (_) => setState(() => _itemsVisibles = 100),
                  ),
                ),
                const SizedBox(width: 8),
                BotonMasWidget(
                  onPressed: () => DialogoProducto.mostrar(
                    context,
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchCtrl,
            builder: (context, value, child) {
              final query = value.text.toLowerCase().trim();
              final filtrados = query.isEmpty
                  ? todos
                  : todos.where((p) {
                      return p.nombre.toLowerCase().contains(query) ||
                          p.sku.toLowerCase().contains(query) ||
                          (p.categoriaNombre?.toLowerCase().contains(query) ??
                              false);
                    }).toList();

              if (filtrados.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Sin resultados',
                      style:
                          TextStyle(color: ColoresApp.textLight, fontSize: 13),
                    ),
                  ),
                );
              }

              final visibles = filtrados.take(_itemsVisibles).toList();

              return Column(
                children: [
                  ...visibles.map(
                    (p) => _FilaProducto(
                      producto: p,
                      ordenId: widget.ordenId,
                    ),
                  ),
                  if (filtrados.length > _itemsVisibles)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _itemsVisibles += 100),
                        icon: const Icon(Icons.expand_more_rounded, size: 16),
                        label: Text(
                          'Cargar más (${filtrados.length - _itemsVisibles} restantes)',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ColoresApp.textMedium,
                          side: const BorderSide(color: ColoresApp.border),
                          minimumSize: const Size.fromHeight(36),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 8),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilaProducto extends ConsumerWidget {
  const _FilaProducto({required this.producto, required this.ordenId});
  final Producto producto;
  final int ordenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sinStock = producto.stockActual <= 0;

    return InkWell(
      onTap: sinStock
          ? null
          : () => showDialog<void>(
                context: context,
                builder: (_) => DialogoCantidadRepuesto(
                  producto: producto,
                  ordenId: ordenId,
                ),
              ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: sinStock
                          ? ColoresApp.textLight
                          : ColoresApp.textDark,
                    ),
                  ),
                  Text(
                    'SKU: ${producto.sku}'
                    '${producto.categoriaNombre != null ? ' · ${producto.categoriaNombre}' : ''}',
                    style: const TextStyle(
                        fontSize: 11.5, color: ColoresApp.textLight),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _StockBadge(producto: producto),
            const SizedBox(width: 10),
            Text(
              _fmtPrecio(producto.precioVentaTaller ?? producto.precioVenta),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ColoresApp.textDark,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.add_circle_outline_rounded,
              size: 20,
              color: sinStock ? ColoresApp.textLight : ColoresApp.primary,
            ),
          ],
        ),
      ),
    );
  }

  String _fmtPrecio(num v) {
    String s = v.abs().toStringAsFixed(2);
    final p = s.split('.');
    p[0] = p[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '\$ ${p[0]}.${p[1]}';
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.producto});
  final Producto producto;

  @override
  Widget build(BuildContext context) {
    final sinStock = producto.stockActual <= 0;
    final bajoPedido = !sinStock && producto.stockActual <= producto.stockMinimo;

    final bg = sinStock
        ? ColoresApp.statusDebtBg
        : bajoPedido
            ? ColoresApp.statusPendingBg
            : ColoresApp.statusPaidBg;

    final fg = sinStock
        ? ColoresApp.statusDebt
        : bajoPedido
            ? ColoresApp.statusPending
            : ColoresApp.statusPaid;

    final label = sinStock
        ? 'Sin stock'
        : 'Stock: ${producto.stockActual % 1 == 0 ? producto.stockActual.toInt() : producto.stockActual}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// Diálogo para confirmar cantidad y precio al agregar desde búsqueda
class DialogoCantidadRepuesto extends ConsumerStatefulWidget {
  const DialogoCantidadRepuesto({
    super.key,
    required this.producto,
    required this.ordenId,
  });
  final Producto producto;
  final int ordenId;

  @override
  ConsumerState<DialogoCantidadRepuesto> createState() =>
      _DialogoCantidadRepuestoState();
}

class _DialogoCantidadRepuestoState
    extends ConsumerState<DialogoCantidadRepuesto> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cantCtrl;
  late final TextEditingController _precioCtrl;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cantCtrl = TextEditingController(text: '1');
    _precioCtrl = TextEditingController(
      text: (widget.producto.precioVentaTaller ?? widget.producto.precioVenta)
          .toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _cantCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _agregar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final cant  = double.parse(_cantCtrl.text.trim());
    // Los importes se guardan en pesos enteros: el redondeo va aquí, al
    // leer el campo, no en el repositorio.
    final precio = double.parse(_precioCtrl.text.trim()).round();

    final error = await ref.read(ordenesProvider.notifier).agregarRepuesto(
          widget.ordenId,
          productoId:     widget.producto.id!,
          cantidad:       cant,
          precioUnitario: precio,
        );

    if (!mounted) return;

    if (error != null) {
      SnackBarMensaje.error(context, error);
      setState(() => _guardando = false);
    } else {
      Navigator.of(context).pop();
      SnackBarMensaje.success(
          context, '${widget.producto.nombre} agregado a la orden.');
    }
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: ColoresApp.textLight, fontSize: 13.5),
        filled: true,
        fillColor: ColoresApp.bgContent,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: ColoresApp.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: ColoresApp.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide:
                const BorderSide(color: ColoresApp.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: ColoresApp.statusDebt)),
      );

  @override
  Widget build(BuildContext context) {
    final stockMax = widget.producto.stockActual;

    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 380,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        color: ColoresApp.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.producto.nombre,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: ColoresApp.textDark,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded,
                          color: ColoresApp.textMedium, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: ColoresApp.bgContent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Stock disponible: $stockMax',
                  style: const TextStyle(
                      fontSize: 12, color: ColoresApp.textMedium),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cantidad',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _cantCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,3}')),
                  ],
                  decoration: _deco('1'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido.';
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return 'Debe ser > 0.';
                    if (n > stockMax) return 'Máximo disponible: $stockMax.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                const Text(
                  'Precio unitario',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: ColoresApp.bgContent,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: ColoresApp.border),
                  ),
                  child: Row(
                    children: [
                      Text(
                        fmtMoneda(widget.producto.precioVentaTaller ??
                            widget.producto.precioVenta),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: ColoresApp.textDark,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.lock_outline_rounded,
                          size: 14, color: ColoresApp.textLight),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Subtotal',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                PrecioCopWidget(
                  controller: _cantCtrl,
                  multiplicador: (widget.producto.precioVentaTaller ??
                          widget.producto.precioVenta)
                      .toDouble(),
                  etiqueta: 'Total:',
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ColoresApp.textMedium,
                          side: const BorderSide(color: ColoresApp.border),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9)),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _guardando ? null : _agregar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColoresApp.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9)),
                          elevation: 0,
                        ),
                        child: _guardando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Agregar',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
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
