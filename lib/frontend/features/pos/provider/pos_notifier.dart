import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../../../core/resultado.dart';
import '../../ventas/facturas/provider/facturas_providers.dart';
import '../modelo/pos_state.dart';

/// El carrito del punto de venta y el cobro de la venta de mostrador.
///
/// La aritmética del carrito vive en [PosState]: aquí queda el "cuándo"
/// —cobrar, avisar, limpiar—, que es lo que necesita a Riverpod de por medio.
class PosNotifier extends Notifier<PosState> {
  @override
  PosState build() => const PosState();

  // ── Catálogo ──────────────────────────────────────────────────────────────

  /// Buscar y filtrar **vuelven a la primera página**: quedarse en la cuarta
  /// después de acotar el catálogo deja la rejilla vacía sin explicar por qué.
  void buscar(String texto) =>
      state = state.copyWith(busqueda: texto.trim(), pagina: 0);

  void filtrarPorCategoria(int? categoriaId) =>
      state = state.copyWith(categoriaId: categoriaId, pagina: 0);

  void irAPagina(int pagina) =>
      state = state.copyWith(pagina: pagina < 0 ? 0 : pagina);

  // ── Carrito ───────────────────────────────────────────────────────────────

  void agregarProducto(Producto producto) => state = state.conProducto(producto);

  void cambiarCantidad(int indice, int cantidad) =>
      state = state.conCantidad(indice, cantidad);

  void quitarLinea(int indice) => state = state.sinLinea(indice);

  void vaciar() => state = state.copyWith(items: const [], descuento: 0);

  void cambiarDescuento(int valor) => state = state.conDescuento(valor);

  void seleccionarCliente(Cliente? cliente) =>
      state = state.copyWith(cliente: cliente);

  // ── Cobro ─────────────────────────────────────────────────────────────────

  /// Crea la factura de mostrador con todas las líneas del carrito y la marca
  /// pagada.
  ///
  /// **Toda venta de mostrador se cobra completa**: no hay pago parcial ni
  /// deuda automática. Fiar es una decisión que se toma con el cliente
  /// delante, no un botón del carrito; para eso está Cuentas por cobrar.
  ///
  /// Al terminar bien, el carrito queda vacío y listo para la siguiente venta.
  Future<Resultado> cobrar({required MetodoPago metodoPago}) async {
    if (state.vacio) {
      return const Fallo(MotivoFallo.validacion, 'El carrito está vacío.');
    }
    if (state.procesando) {
      return const Fallo(MotivoFallo.validacion, 'La venta ya se está cobrando.');
    }

    state = state.copyWith(procesando: true);
    final venta = state;

    try {
      final facturas = ref.read(facturasProvider.notifier);

      final errorCrear = await facturas.crear(
        tipo: TipoVenta.mostrador,
        clienteId: venta.cliente?.id,
        metodoPago: metodoPago,
        estadoPago: EstadoPago.pagado,
        iva: venta.iva,
        descuento: venta.descuento,
      );
      if (errorCrear != null) {
        return Fallo(MotivoFallo.persistencia, errorCrear);
      }

      // El repositorio devuelve las facturas más recientes primero, así que la
      // recién creada es la primera. No hay forma de pedirle el id a `crear`.
      final creada = ref.read(facturasProvider).value?.facturas.firstOrNull;
      if (creada == null) {
        return const Fallo(
          MotivoFallo.persistencia,
          'La venta se creó pero no se pudo leer para agregarle los productos.',
        );
      }

      for (final linea in venta.items) {
        final errorItem = await facturas.agregarItem(
          ventaId: creada.id,
          tipoItem: TipoItem.producto,
          productoId: linea.producto.id,
          descripcion: linea.producto.nombre,
          cantidad: linea.cantidad.toDouble(),
          precioUnitario: linea.precioUnitario,
          costoUnitario: linea.producto.precioCompra,
        );
        if (errorItem != null) {
          return Fallo(MotivoFallo.persistencia, errorItem);
        }
      }

      final errorCobro = await facturas.cobrar(
        id: creada.id,
        totalPagado: venta.total,
        totalFactura: venta.total,
        estadoPago: EstadoPago.pagado,
        metodoPago: metodoPago,
      );
      if (errorCobro != null) {
        return Fallo(MotivoFallo.persistencia, errorCobro);
      }

      state = const PosState();
      return const Exito();
    } catch (e) {
      return Fallo(MotivoFallo.persistencia, 'No se pudo cobrar la venta: $e');
    } finally {
      if (state.procesando) state = state.copyWith(procesando: false);
    }
  }
}
