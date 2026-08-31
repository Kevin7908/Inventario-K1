import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../../backend/features/pos/enum/enum_ventas.dart';
import '../../../../backend/features/pos/modelo/linea_venta_mostrador.dart';
import '../../../../core/resultado.dart';
import '../modelo/pos_state.dart';
import 'pos_providers.dart';

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

  /// Cobra el carrito: registra la venta de mostrador con todas sus líneas y
  /// la deja pagada.
  ///
  /// **Una sola llamada al repositorio.** Antes esto encadenaba la cabecera,
  /// una línea por producto y el cobro desde aquí, y encima recuperaba el id
  /// leyendo la venta más reciente de la lista: si algo fallaba a mitad
  /// quedaba una venta con su consecutivo quemado, sin productos y sin cobrar.
  /// La transacción vive donde tiene que vivir, en el repositorio (§6 de las
  /// reglas de base de datos).
  ///
  /// Al terminar bien, el carrito queda vacío y listo para la siguiente venta.
  ///
  /// Devuelve también el **id de la venta creada**, que es lo que necesita
  /// «Cobrar e imprimir» para levantar la factura recién emitida. Va en un
  /// record y no dentro de `Exito` porque `Resultado` no es genérico y hacerlo
  /// genérico tocaría los veinte repositorios para un solo caso. En el fallo
  /// es `null`.
  Future<({Resultado resultado, int? ventaId})> cobrar({
    required MetodoPago metodoPago,
  }) async {
    if (state.vacio) {
      return (
        resultado: const Fallo(MotivoFallo.validacion, 'El carrito está vacío.'),
        ventaId: null,
      );
    }
    if (state.procesando) {
      return (
        resultado: const Fallo(
            MotivoFallo.validacion, 'La venta ya se está cobrando.'),
        ventaId: null,
      );
    }

    // `Producto.id` es nulo hasta que el producto se guarda, así que el tipo
    // obliga a descartar el caso. Un producto sin id no está en el catálogo y
    // no se puede vender: mejor no cobrar que cobrar una línea suelta.
    if (state.items.any((i) => i.producto.id == null)) {
      return (
        resultado: const Fallo(
          MotivoFallo.validacion,
          'Hay un producto del carrito que ya no está en el catálogo.',
        ),
        ventaId: null,
      );
    }

    state = state.copyWith(procesando: true);
    final venta = state;

    try {
      final resumen =
          await ref.read(repositorioVentasProvider).registrarVentaMostrador(
            lineas: [
              for (final linea in venta.items)
                LineaVentaMostrador(
                  productoId: linea.producto.id!,
                  descripcion: linea.producto.nombre,
                  cantidad: linea.cantidad.toDouble(),
                  precioUnitario: linea.precioUnitario,
                  costoUnitario: linea.producto.precioCompra,
                ),
            ],
            metodoPago: metodoPago,
            clienteId: venta.cliente?.id,
            iva: venta.iva,
            descuento: venta.descuento,
          );

      state = const PosState();
      return (resultado: const Exito(), ventaId: resumen.id);
    } catch (e) {
      return (
        resultado:
            Fallo(MotivoFallo.persistencia, 'No se pudo cobrar la venta: $e'),
        ventaId: null,
      );
    } finally {
      if (state.procesando) state = state.copyWith(procesando: false);
    }
  }
}
