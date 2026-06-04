import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../backend/features/productos/modelo/producto.dart';
import '../../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../../../../../backend/share/database/locator.dart';
import '../../../../../share/formateadores/moneda_formateador.dart';
import '../../../../../share/temas/colores_app.dart';
import '../../../../../share/widgets/botones/boton_mas_widget.dart';
import '../../../../../share/widgets/output/precio_cop_widget.dart';
import '../../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../../../productos/provider/productos_provider.dart';
import '../../../../productos/widgets/dialogo_producto_widget.dart';
import '../../../../proveedores/view_model/proveedores_view_model.dart';
import '../../provider/facturas_provider.dart';

class PanelBusquedaProductosFactura extends ConsumerStatefulWidget {
  const PanelBusquedaProductosFactura({super.key, required this.facturaId});
  final int facturaId;

  @override
  ConsumerState<PanelBusquedaProductosFactura> createState() =>
      _PanelBusquedaProductosFacturaState();
}

class _PanelBusquedaProductosFacturaState
    extends ConsumerState<PanelBusquedaProductosFactura> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(productosProvider).value?.todos ?? const [];
    final filtrados = _query.isEmpty
        ? todos
        : todos
            .where((p) =>
                p.nombre.toLowerCase().contains(_query) ||
                p.sku.toLowerCase().contains(_query))
            .toList(growable: false);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresApp.border),
        boxShadow: const [
          BoxShadow(color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: Color(0xFFDBEAFE))),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: ColoresApp.primary, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                const Text(
                  'AGREGAR PRODUCTO DEL INVENTARIO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: ColoresApp.primary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) =>
                        setState(() => _query = v.toLowerCase().trim()),
                    style: const TextStyle(
                        fontSize: 13.5, color: ColoresApp.textDark),
                    decoration: InputDecoration(
                      hintText: 'Buscar producto por nombre o código...',
                      hintStyle: const TextStyle(
                          color: ColoresApp.textLight, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: ColoresApp.textLight, size: 18),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  size: 16, color: ColoresApp.textLight),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
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
                  ),
                ),
                const SizedBox(width: 8),
                BotonMasWidget(
                  onPressed: () => DialogoProducto.mostrar(
                    context,
                    proveedoresVm: locator<ProveedoresViewModel>(),
                  ),
                ),
              ],
            ),
          ),
          if (filtrados.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Sin resultados',
                  style: TextStyle(
                      fontSize: 13,
                      color: ColoresApp.textLight,
                      fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtrados.length,
              itemBuilder: (_, i) => _FilaProducto(
                key: ValueKey(filtrados[i].id),
                producto: filtrados[i],
                facturaId: widget.facturaId,
              ),
            ),
        ],
      ),
    );
  }
}

class _FilaProducto extends StatelessWidget {
  const _FilaProducto({super.key, required this.producto, required this.facturaId});
  final Producto producto;
  final int facturaId;

  void _abrirDialogo(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoCantidadProducto(
        producto: producto,
        facturaId: facturaId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sinStock = producto.stockActual <= 0;

    return InkWell(
      onTap: sinStock ? null : () => _abrirDialogo(context),
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
                    producto.sku,
                    style: const TextStyle(
                        fontSize: 11, color: ColoresApp.textLight),
                  ),
                ],
              ),
            ),
            Text(
              fmtMoneda(
                  producto.precioVentaTaller ?? producto.precioVenta),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ColoresApp.textDark),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: sinStock
                    ? ColoresApp.statusDebtBg
                    : ColoresApp.statusPaidBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                sinStock
                    ? 'Sin stock'
                    : 'Stock: ${producto.stockActual.toInt()}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: sinStock ? ColoresApp.statusDebt : ColoresApp.statusPaid,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogoCantidadProducto extends ConsumerStatefulWidget {
  const _DialogoCantidadProducto({
    required this.producto,
    required this.facturaId,
  });

  final Producto producto;
  final int facturaId;

  @override
  ConsumerState<_DialogoCantidadProducto> createState() =>
      _DialogoCantidadProductoState();
}

class _DialogoCantidadProductoState
    extends ConsumerState<_DialogoCantidadProducto> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cantCtrl;
  bool _guardando = false;

  late final double _precioFijo;

  @override
  void initState() {
    super.initState();
    _cantCtrl = TextEditingController(text: '1');
    _precioFijo = widget.producto.precioVentaTaller ??
        widget.producto.precioVenta;
  }

  @override
  void dispose() {
    _cantCtrl.dispose();
    super.dispose();
  }

  Future<void> _agregar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final cantidad = double.tryParse(_cantCtrl.text.trim()) ?? 1;
    final error = await ref.read(facturasProvider.notifier).agregarItem(
          ventaId:        widget.facturaId,
          tipoItem:       TipoItem.producto,
          productoId:     widget.producto.id,
          descripcion:    widget.producto.nombre,
          cantidad:       cantidad,
          precioUnitario: _precioFijo,
          costoUnitario:  widget.producto.precioCompra,
        );

    if (!mounted) return;
    if (error != null) {
      SnackBarMensaje.error(context, error);
      setState(() => _guardando = false);
    } else {
      Navigator.of(context).pop();
      SnackBarMensaje.success(context, 'Producto agregado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.producto.nombre,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.textDark),
              ),
              const SizedBox(height: 16),

              // Precio (solo lectura)
              const Text(
                'PRECIO UNITARIO',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: ColoresApp.textLight),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: ColoresApp.bgContent,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: ColoresApp.border),
                ),
                child: Row(
                  children: [
                    Text(
                      fmtMoneda(_precioFijo),
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: ColoresApp.textDark),
                    ),
                    const Spacer(),
                    const Icon(Icons.lock_outline_rounded,
                        size: 14, color: ColoresApp.textLight),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'CANTIDAD *',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: ColoresApp.textLight),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _cantCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                autofocus: true,
                decoration: _deco('1'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido.';
                  final n = double.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Debe ser mayor a 0.';
                  final stock = widget.producto.stockActual;
                  if (n > stock) {
                    return 'Stock disponible: ${stock % 1 == 0 ? stock.toInt() : stock.toStringAsFixed(2)}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              PrecioCopWidget(
                controller: _cantCtrl,
                multiplicador: _precioFijo,
                etiqueta: 'Total:',
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _guardando
                          ? null
                          : () => Navigator.of(context).pop(),
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
                      onPressed: _guardando ? null : _agregar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColoresApp.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Agregar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: ColoresApp.textLight, fontSize: 13.5),
        filled: true,
        fillColor: ColoresApp.bgContent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ColoresApp.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ColoresApp.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ColoresApp.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ColoresApp.statusDebt)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ColoresApp.statusDebt, width: 1.5)),
      );
}
