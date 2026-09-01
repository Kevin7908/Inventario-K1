import '../../../../core/resultado.dart';
import '../enum/enum_devoluciones.dart';
import '../modelo/devolucion.dart';

/// Lo que el cliente trae de vuelta de una venta ya cobrada.
///
/// **Anular y devolver no son lo mismo.** Anular (`RepositorioVentas.anular`)
/// deshace la venta entera y la deja en `ANULADA`; devolver le quita una parte
/// y la factura sigue viva. Las dos reponen stock —salvo la devolución que
/// dice que no, ver [registrar]— y las dos lo hacen por
/// `RepositorioInventario`: ningún `UPDATE productos SET stock_actual` vive
/// fuera de ahí.
abstract interface class RepositorioDevoluciones {
  /// Qué se puede devolver todavía de cada línea de la venta.
  ///
  /// Descuenta en SQL lo ya devuelto por documentos anteriores: la vista no
  /// resta listas en memoria. Incluye las líneas de servicio —para poder
  /// devolver la plata de un trabajo que no se hizo— con [LineaDevolvible
  /// .productoId] en `null`.
  Future<List<LineaDevolvible>> lineasDevolvibles(int ventaId);

  /// Registra la devolución entera: cabecera, líneas y las entradas de
  /// inventario, todo en una transacción.
  ///
  /// **Es una sola operación de negocio, así que es un solo método**
  /// (`REGLAS_BD.md` §6). El total no se recibe: se calcula con el precio al
  /// que se vendió cada línea, que es el único que no puede discutirse.
  ///
  /// [reingresaStock] decide si la mercancía vuelve al estante. En `false` se
  /// guarda el documento y se le regresa la plata al cliente, pero **no se
  /// escribe ningún movimiento de inventario**: la pieza llegó rota y se le
  /// reclama al proveedor, no se vuelve a vender. Si no se pasa, lo propone el
  /// motivo (`MotivoDevolucion.reponeStockPorDefecto`).
  ///
  /// Devuelve [Fallo] con [MotivoFallo.validacion] si no hay líneas, si
  /// alguna cantidad se pasa de lo que queda, o si la venta está anulada.
  Future<Resultado> registrar({
    required int ventaId,
    required MotivoDevolucion motivo,
    required List<LineaADevolver> lineas,
    bool? reingresaStock,
    String? notas,
  });

  /// Las devoluciones de una venta, de la más reciente a la más antigua, con
  /// sus líneas ya resueltas.
  Stream<List<Devolucion>> observarPorVenta(int ventaId);

  /// Cuánto se ha devuelto de cada línea de [ventaId], indexado por
  /// `venta_detalles.id`. Las líneas sin devoluciones no aparecen.
  Future<Map<int, double>> devueltoPorLinea(int ventaId);

  /// Lo devuelto en total de cada venta, indexado por `ventas.id`.
  ///
  /// Existe para que el historial pueda decir «se devolvieron $30.000 de esta
  /// factura» sin una consulta por fila, que es el N+1 que prohíbe §5.
  Stream<Map<int, int>> observarTotalDevueltoPorVenta();

  /// Las devoluciones cuyo caché [Devolucion.total] no cuadra con la suma de
  /// sus líneas, con la diferencia (`caché − líneas`).
  ///
  /// Vacío es lo esperado. Es la comprobación que hace legítimo tener el
  /// caché (`REGLAS_BD.md` §7).
  Future<Map<int, int>> descuadres();
}
