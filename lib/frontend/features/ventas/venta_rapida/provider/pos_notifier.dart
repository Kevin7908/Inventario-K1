import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/core/iva_app.dart';

import '../../../../../backend/features/productos/modelo/producto.dart';
import '../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../facturas/provider/facturas_providers.dart';
import 'pos_state.dart';

class PosNotifier extends Notifier<PosState> {
  @override
  PosState build() => const PosState();

  // ── Catálogo ──────────────────────────────────────────────────────────────

  void buscar(String query) =>
      state = state.copyWith(buscando: query.trim());

  void filtrarCategoria(String? categoria) =>
      state = state.copyWith(categoriaFiltro: categoria);

  // ── Carrito ───────────────────────────────────────────────────────────────

  void agregar(Producto producto) {
    if (producto.stockActual <= 0) return;

    final items   = List<ItemCarrito>.of(state.items);
    final idx     = items.indexWhere((i) => i.producto.id == producto.id);
    final maxQty  = producto.stockActual.floor();

    if (idx == -1) {
      items.add(ItemCarrito(producto: producto, cantidad: 1));
    } else {
      final actual = items[idx].cantidad;
      if (actual >= maxQty) return;
      items[idx] = items[idx].copyWith(cantidad: actual + 1);
    }
    state = state.copyWith(items: items);
  }

  void reducir(int productoId) {
    final items = List<ItemCarrito>.of(state.items);
    final idx   = items.indexWhere((i) => i.producto.id == productoId);
    if (idx == -1) return;

    final actual = items[idx].cantidad;
    if (actual <= 1) {
      items.removeAt(idx);
    } else {
      items[idx] = items[idx].copyWith(cantidad: actual - 1);
    }
    state = state.copyWith(items: items);
  }

  void eliminar(int productoId) {
    state = state.copyWith(
      items: state.items
          .where((i) => i.producto.id != productoId)
          .toList(growable: false),
    );
  }

  void vaciarCarrito() => state = state.copyWith(items: const [], descuento: 0);

  void cambiarDescuento(double valor) =>
      state = state.copyWith(descuento: valor < 0 ? 0 : valor);

  // ── Cliente / Pago ────────────────────────────────────────────────────────

  void seleccionarCliente(int? id, String? nombre) =>
      state = state.copyWith(clienteId: id, clienteNombre: nombre);

  void cambiarMetodoPago(MetodoPago metodo) =>
      state = state.copyWith(metodoPago: metodo);

  // ── Checkout ──────────────────────────────────────────────────────────────

  /// Crea la factura con todos los ítems del carrito.
  /// Retorna null si ok, o el mensaje de error.
  Future<String?> procesarVenta({
    EstadoPago estadoPago = EstadoPago.pagado,
  }) async {
    if (state.items.isEmpty) return 'El carrito está vacío.';
    state = state.copyWith(procesando: true);

    try {
      final notifier  = ref.read(facturasProvider.notifier);
      final subtotal  = state.subtotal;
      final ivaAmount = subtotal * kIva;

      final error = await notifier.crear(
        tipo:       TipoVenta.mostrador,
        clienteId:  state.clienteId,
        metodoPago: state.metodoPago,
        estadoPago: estadoPago,
        iva:        ivaAmount,
        descuento:  state.descuento,
      );
      if (error != null) return error;

      // Obtener el id de la factura recién creada.
      final facturas   = ref.read(facturasProvider).value?.facturas ?? const [];
      final nuevaFact  = facturas.isNotEmpty ? facturas.first : null;
      if (nuevaFact == null) return 'No se pudo obtener la factura creada.';

      for (final item in state.items) {
        final errItem = await notifier.agregarItem(
          ventaId:        nuevaFact.id,
          tipoItem:       TipoItem.producto,
          productoId:     item.producto.id,
          descripcion:    item.producto.nombre,
          cantidad:       item.cantidad.toDouble(),
          precioUnitario: item.producto.precioVenta,
          costoUnitario:  item.producto.precioCompra,
        );
        if (errItem != null) return errItem;
      }

      state = const PosState(); // resetea el carrito
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      if (state.procesando) {
        state = state.copyWith(procesando: false);
      }
    }
  }
}
