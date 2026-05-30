import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/core/currency_ext.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/widgets/input/app_searc_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/output/snack_bar_mensaje.dart';

import 'package:inventario_k1/backend/features/cotizaciones/enum/enum_cotizacion.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/share/database/locator.dart';
import 'package:inventario_k1/frontend/features/cotizaciones/provider/cotizaciones_provider.dart';
import 'package:inventario_k1/frontend/features/productos/widgets/dialogo_producto_widget.dart';
import 'package:inventario_k1/frontend/features/proveedores/view_model/proveedores_view_model.dart';
import 'agregar_item_shared.dart';

class DialogoAgregarProducto extends ConsumerStatefulWidget {
  const DialogoAgregarProducto({
    super.key,
    required this.cotizacionId,
    this.onAgregado,
  });

  final int cotizacionId;
  final VoidCallback? onAgregado;

  static Future<void> mostrar(
    BuildContext context, {
    required int cotizacionId,
    VoidCallback? onAgregado,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => DialogoAgregarProducto(
        cotizacionId: cotizacionId,
        onAgregado: onAgregado,
      ),
    );
  }

  @override
  ConsumerState<DialogoAgregarProducto> createState() =>
      _DialogoAgregarProductoState();
}

class _DialogoAgregarProductoState
    extends ConsumerState<DialogoAgregarProducto> {
  final _productoNotifier = ValueNotifier<Producto?>(null);
  final _cantCtrl = TextEditingController(text: '1');

  // Precio viene de la relación con el producto — no es editable por el usuario
  int _precio = 0;
  bool _cargando = false;

  int get _cantidad => int.tryParse(_cantCtrl.text) ?? 1;
  int get _subtotal => _cantidad * _precio;

  @override
  void dispose() {
    _productoNotifier.dispose();
    _cantCtrl.dispose();
    super.dispose();
  }

  Future<void> _agregar() async {
    final producto = _productoNotifier.value;
    if (producto == null || _precio <= 0) return;
    setState(() => _cargando = true);

    final error = await ref.read(cotizacionesProvider.notifier).agregarItem(
          cotizacionId: widget.cotizacionId,
          tipo: TipoItemCotizacion.producto,
          referenciaId: producto.id,
          descripcion: producto.nombre,
          cantidad: _cantidad.toDouble(),
          precioUnitario: _precio,
        );

    if (!mounted) return;
    setState(() => _cargando = false);

    if (error != null) {
      SnackBarMensaje.error(context, error);
      return;
    }
    widget.onAgregado?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final productos =
        ref.watch(productosParaCotizacionProvider).value ?? <Producto>[];

    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AgregarItemHeader(
                titulo: 'Agregar Producto',
                icono: Icons.inventory_2_outlined,
                onCerrar: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 20),

              const AgregarItemLabel('Producto'),
              const SizedBox(height: 6),
              AppSearch<Producto>(
                notifier: _productoNotifier,
                items: productos,
                labelBuilder: (p) => p.nombre,
                hint: 'Buscar producto...',
                onAgregar: () {
                  // Abrir creación de producto y refrescar lista al regresar
                  DialogoProducto.mostrar(
                    context,
                    proveedoresVm: locator<ProveedoresViewModel>(),
                  ).then((_) => ref.invalidate(productosParaCotizacionProvider));
                },
                onChanged: (p) {
                  if (p != null) {
                    setState(() => _precio = p.precioVenta.round());
                  }
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AgregarItemLabel('Cantidad'),
                        const SizedBox(height: 6),
                        AgregarNumericField(
                          controller: _cantCtrl,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AgregarItemLabel('Precio unitario (\$)'),
                        const SizedBox(height: 6),
                        _PrecioAutoField(precio: _precio),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              AgregarSubtotalRow(subtotal: _subtotal),
              const SizedBox(height: 20),

              AgregarItemBotones(
                cargando: _cargando,
                habilitado: _productoNotifier.value != null && _precio > 0,
                onCancelar: () => Navigator.of(context).pop(),
                onAgregar: _agregar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Campo de precio de solo lectura — se auto-completa al seleccionar un producto.
class _PrecioAutoField extends StatelessWidget {
  const _PrecioAutoField({required this.precio});

  final int precio;

  @override
  Widget build(BuildContext context) {
    final tieneValor = precio > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresApp.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            tieneValor ? precio.toCopString() : 'Se auto-completa al elegir',
            style: TextStyle(
              color: tieneValor ? ColoresApp.textDark : ColoresApp.textLight,
              fontSize: 13.5,
              fontStyle:
                  tieneValor ? FontStyle.normal : FontStyle.italic,
            ),
          ),
          const Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: ColoresApp.textLight,
          ),
        ],
      ),
    );
  }
}
