import '../../../../core/resultado.dart';
import '../../../share/dominio/metodo_pago.dart';
import '../enum/enum_deudor.dart';
import '../modelo/deudor_detalle.dart';
import '../modelo/deudor_resumen.dart';
import '../resultado/resultado_cierre_credito.dart';

/// En qué tramo de la cartera se está mirando.
///
/// **No es el enum de estados.** `EstadoDeudor` dice qué se guardó en la fila;
/// esto dice qué pregunta se está haciendo el que mira la pantalla, y las dos
/// no coinciden: una deuda `ACTIVA` cuyo plazo ya pasó está **vencida** aunque
/// nadie la haya marcado. Filtrar por `estado = 'VENCIDA'` dejaría fuera
/// justamente las que hay que ir a cobrar.
enum VistaDeudores {
  /// Toda la cartera, cerrada incluida.
  todas,

  /// Vivas y dentro del plazo.
  alDia,

  /// Vivas con el plazo cumplido, o marcadas a mano como vencidas.
  vencidas,

  /// Ya cobradas.
  pagadas,
}

/// Criterios del listado, traducidos a un `WHERE` por el repositorio.
///
/// Value object con igualdad estructural: reabrir el stream con el mismo
/// filtro no cuenta como cambio y no dispara una consulta de más.
final class FiltroDeudores {
  const FiltroDeudores({
    this.busqueda = '',
    this.vista = VistaDeudores.todas,
  });

  /// Texto libre. Busca en el número de la deuda, en el concepto y en el
  /// nombre del cliente.
  final String busqueda;

  final VistaDeudores vista;

  @override
  bool operator ==(Object other) =>
      other is FiltroDeudores &&
      other.busqueda == busqueda &&
      other.vista == vista;

  @override
  int get hashCode => Object.hash(busqueda, vista);
}

/// Un tramo del listado más el total real.
///
/// [total] cuenta **todas** las deudas que cumplen el filtro, no las de la
/// página: es lo que necesita el paginador para saber cuántas hay.
final class PaginaDeudores {
  const PaginaDeudores({required this.items, required this.total});

  final List<DeudorResumen> items;
  final int total;

  static const vacia = PaginaDeudores(items: [], total: 0);
}

/// Los cuatro números que encabezan la pantalla.
///
/// [porCobrar] es plata —la suma de los saldos vivos—; los otros tres son
/// conteos. Salen de una sola pasada con `COUNT`/`SUM` filtrados, no de
/// recorrer la cartera en Dart (§5 de `REGLAS_BD.md`): la pantalla los quiere
/// sobre el total aunque la búsqueda esté recortando la tabla.
typedef ResumenCartera = ({
  int porCobrar,
  int alDia,
  int vencidas,
  int pagadas,
});

abstract class RepositorioDeudores {
  /// Una página del listado. El `WHERE`, el `COUNT` y el `LIMIT` los resuelve
  /// SQLite: la cartera de un taller crece y no se cierra sola.
  ///
  /// [pagina] es de base cero.
  Stream<PaginaDeudores> observarPagina({
    required FiltroDeudores filtro,
    required int pagina,
    required int tamano,
  });

  /// Los contadores de la cabecera, sobre la cartera entera.
  Stream<ResumenCartera> observarResumen();

  Future<DeudorDetalle> obtenerDetalle(int id);

  /// Abre una deuda **vacía** y devuelve su id.
  ///
  /// Nace en cero y se le van anotando los repuestos con [agregarItem], igual
  /// que una reserva: el monto es la suma de las líneas, no un número que se
  /// teclee.
  ///
  /// Lanza si la base la rechaza, igual que `RepositorioReservas.crear`: quien
  /// la llama es un diálogo que solo puede hacer una cosa con el fallo, que es
  /// enseñarlo.
  Future<int> crear({
    required int clienteId,
    int? motoId,
    String? concepto,
    DateTime? fechaVencimiento,
    String? notas,
  });

  /// Cierra una orden de servicio **a crédito**: abre la deuda con lo que la
  /// orden cobra ya dentro y deja las dos enlazadas.
  ///
  /// Es la operación que cierra el descuento doble de inventario. Antes había
  /// que anotar el repuesto en la orden —que lo saca del estante— y otra vez
  /// en la deuda para que constara qué se fió, y el inventario descontaba las
  /// dos veces. Aquí las líneas se **copian**: repuestos, mano de obra y
  /// cargos, con su descripción congelada, y **no se registra ni un
  /// movimiento**, porque la mercancía ya salió.
  ///
  /// En la misma transacción la orden pasa a `ENTREGADA` con su fecha de
  /// salida: la moto se va con el cliente, que es lo que significa fiar.
  ///
  /// Una orden se fía **una sola vez** —lo garantiza el `UNIQUE` de
  /// `deudores.orden_id`—, y las líneas de la deuda que resulta no se editan
  /// a mano: hay una guarda en la base que lo impide, porque editarlas movería
  /// stock por una salida que ya ocurrió.
  ///
  /// Exige `DEUDORES_CREAR` y `ORDENES_EDITAR`: abre una deuda y cierra una
  /// orden.
  Future<ResultadoCierreCredito> cerrarOrdenACredito({
    required int ordenId,
    DateTime? fechaVencimiento,
    String? notas,
  });

  /// Cambia los datos de la cabecera. **El monto no está aquí**: sale de las
  /// líneas.
  Future<Resultado> actualizar({
    required int id,
    int? motoId,
    String? concepto,
    DateTime? fechaVencimiento,
    String? notas,
  });

  // Líneas, una a una
  //
  // Mismo modelo que reservas y órdenes: el editor escribe por línea y no
  // reemplazando la deuda entera, porque cada línea mueve inventario y
  // reescribirlas todas en cada tecleo serían dos movimientos por línea y por
  // tecla.

  /// Anota un repuesto más como fiado y **lo descuenta del inventario**.
  ///
  /// Si el producto ya está en la deuda se le suma a su línea en vez de abrir
  /// otra. Falla si no hay stock: no se puede fiar lo que no está.
  ///
  /// La descripción no se recibe: se copia del catálogo al insertar, que es
  /// lo que la vuelve un snapshot y no un dato que la vista pueda inventar.
  ///
  /// Falla también si la deuda vino de una orden ([cerrarOrdenACredito]):
  /// esas líneas ya salieron del estante y anotarlas otra vez es el descuento
  /// doble que todo esto vino a cerrar.
  Future<Resultado> agregarItem({
    required int deudorId,
    required int productoId,
    required double cantidad,
    required int precioUnitario,
  });

  /// Cambia la cantidad o el precio de una línea, moviendo **solo la
  /// diferencia** de stock.
  Future<Resultado> actualizarItem(
    int itemId, {
    double? cantidad,
    int? precioUnitario,
  });

  /// Quita la línea y devuelve su mercancía al inventario.
  ///
  /// **Es la corrección de un error de captura, no una devolución del
  /// cliente**: lo fiado ya salió del taller. Quitar una línea significa que
  /// nunca debió anotarse, y por eso el repuesto vuelve al estante.
  ///
  /// Si al quitarla el total queda por debajo de lo que el cliente ya abonó,
  /// se registra un **pago negativo** por la diferencia: esa plata hay que
  /// regresarla, y queda escrita como un movimiento más en vez de corregir los
  /// abonos viejos.
  Future<Resultado> eliminarItem(int itemId);

  /// Anota un abono y recalcula el caché `monto_pagado`.
  ///
  /// Rechaza lo que pase del saldo: cobrar de más siempre es un error de
  /// captura, y dejarlo pasar descuadra la cartera sin que se note.
  Future<Resultado> registrarPago({
    required int deudorId,
    required int monto,
    required MetodoPago metodoPago,
    String? notas,
  });

  Future<Resultado> eliminarPago(int pagoId, int deudorId);

  Future<Resultado> cambiarEstado(int id, EstadoDeudor nuevoEstado);

  Future<Resultado> eliminar(int id);

  /// Las deudas cuyo `monto_pagado` no cuadra con la suma de sus pagos,
  /// indexadas por id y con la diferencia (`caché − suma`).
  ///
  /// Vacío es lo esperado. Existe por el mismo motivo que
  /// `RepositorioInventario.descuadres` y `RepositorioReservas.descuadres`: un
  /// caché solo está justificado si algo puede afirmar que coincide.
  Future<Map<int, int>> descuadres();

  /// Las deudas cuyo `monto_total` no cuadra con la suma de sus líneas,
  /// indexadas por id y con la diferencia (`caché − suma`).
  ///
  /// El segundo caché de la tabla necesita su propia afirmación, igual que el
  /// primero (§7 de `REGLAS_BD.md`).
  Future<Map<int, int>> descuadresTotal();
}
