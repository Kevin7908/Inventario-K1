import '../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../../backend/features/productos/repositorio/repositorio_producto.dart';
import '../../../../core/iva_app.dart';
import 'item_carrito.dart';

/// Todo lo que hay en pantalla mientras se arma una venta de mostrador: el
/// carrito, a quién se le vende y los filtros del catálogo de la izquierda.
///
/// Los filtros viven aquí y no en el widget porque de ellos sale la lista
/// derivada ([productosPosProvider]): filtrar dentro de `build()` repetiría el
/// trabajo en cada repintado.
///
/// La **forma de pago no está**: se elige al cobrar, en el diálogo, que es
/// donde el cliente dice cómo paga. Guardarla antes obligaría a mantener un
/// dato que todavía no existe.
final class PosState {
  const PosState({
    this.items = const [],
    this.cliente,
    this.descuento = 0,
    this.busqueda = '',
    this.categoriaId,
    this.pagina = 0,
    this.procesando = false,
  });

  /// Cuántas tarjetas trae cada página. Doce llena tres filas de cuatro en una
  /// pantalla de mostrador sin obligar a hacer scroll.
  static const int tamanoPagina = 12;

  final List<ItemCarrito> items;

  /// `null` = venta de mostrador, sin cliente registrado. Es el caso normal.
  final Cliente? cliente;

  /// Rebaja en pesos sobre el subtotal. Nunca mayor que él.
  final int descuento;

  final String busqueda;

  /// `null` = todas las categorías.
  final int? categoriaId;

  /// Página de la rejilla, de base cero.
  final int pagina;

  final bool procesando;

  /// Traduce los filtros de la interfaz a los que entiende el repositorio.
  ///
  /// `soloActivos` va fijo: lo dado de baja no se vende. El recorte lo hace
  /// SQLite, no la vista (§7).
  FiltroProductos get filtro => FiltroProductos(
        busqueda: busqueda,
        categoriaId: categoriaId,
        soloActivos: true,
      );

  int get subtotal => items.fold(0, (suma, i) => suma + i.subtotal);

  /// Cuántas unidades hay en el carrito, no cuántas líneas.
  int get unidades => items.fold(0, (suma, i) => suma + i.cantidad);

  /// Lo que se cobra: el carrito menos la rebaja. Los precios ya traen el IVA
  /// dentro (ver `iva_app.dart`), así que no hay nada que sumarle después y el
  /// descuento se resta de lo que paga el cliente.
  int get total => subtotal - descuento;

  /// Cuánto del [total] es impuesto. Informativo: se extrae, no se suma.
  int get iva => ivaIncluidoEn(total);

  bool get vacio => items.isEmpty;

  /// Índice de la línea de ese producto, o -1.
  int indiceDe(int? productoId) =>
      items.indexWhere((i) => i.producto.id == productoId);

  /// Agrega el producto o, si ya está en el carrito, le suma una unidad. Sin
  /// stock disponible devuelve el mismo estado: el mostrador entrega lo que
  /// hay en bodega, a diferencia de una cotización, que puede cotizar lo que
  /// toca pedirle al proveedor.
  PosState conProducto(Producto producto) {
    if (producto.stockActual < 1) return this;

    final i = indiceDe(producto.id);
    if (i < 0) {
      return copyWith(items: [...items, ItemCarrito.deProducto(producto)]);
    }
    return conCantidad(i, items[i].cantidad + 1);
  }

  /// Fija la cantidad de una línea, recortada al stock. Con 0 o menos, quita
  /// la línea: el carrito del diseño no tiene papelera y el `–` en 1 borra.
  PosState conCantidad(int indice, int cantidad) {
    if (indice < 0 || indice >= items.length) return this;
    if (cantidad <= 0) return sinLinea(indice);

    final linea = items[indice];
    final tope = linea.disponible;
    final nueva = cantidad > tope ? tope : cantidad;
    if (nueva == linea.cantidad) return this;

    final lista = [...items];
    lista[indice] = linea.copyWith(cantidad: nueva);
    return copyWith(items: lista);
  }

  PosState sinLinea(int indice) {
    if (indice < 0 || indice >= items.length) return this;
    final lista = [...items]..removeAt(indice);
    // Un descuento mayor que lo que queda por cobrar dejaría un total en
    // negativo, así que se recorta junto con el carrito.
    return copyWith(items: lista).conDescuento(descuento);
  }

  /// Recorta el descuento a lo que se puede rebajar: nunca negativo, nunca
  /// mayor que el subtotal.
  PosState conDescuento(int valor) {
    final tope = subtotal;
    final ajustado = valor < 0 ? 0 : (valor > tope ? tope : valor);
    return copyWith(descuento: ajustado);
  }

  static const Object _sinCambio = Object();

  PosState copyWith({
    List<ItemCarrito>? items,
    Object? cliente = _sinCambio,
    int? descuento,
    String? busqueda,
    Object? categoriaId = _sinCambio,
    int? pagina,
    bool? procesando,
  }) =>
      PosState(
        items: items ?? this.items,
        cliente:
            identical(cliente, _sinCambio) ? this.cliente : cliente as Cliente?,
        descuento: descuento ?? this.descuento,
        busqueda: busqueda ?? this.busqueda,
        categoriaId: identical(categoriaId, _sinCambio)
            ? this.categoriaId
            : categoriaId as int?,
        pagina: pagina ?? this.pagina,
        procesando: procesando ?? this.procesando,
      );
}
