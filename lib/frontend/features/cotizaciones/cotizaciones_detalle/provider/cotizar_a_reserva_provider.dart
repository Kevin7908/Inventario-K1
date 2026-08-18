import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/backend/features/reservas/repositorio/repositorio_reservas.dart';
import 'package:inventario_k1/frontend/features/reservas/provider/reservas_provider.dart';

import '../modelo/item_cotizacion_editor.dart';

/// Use-case de responsabilidad única: convertir una cotización guardada en reserva.
///
/// Mapea [ItemCotizacionEditor] → [ItemReservaDraft] (solo ítems reservables)
/// y delega la creación al [reservasProvider].
final class CotizarAReservaUseCase {
  const CotizarAReservaUseCase(this._ref);

  final Ref _ref;

  /// Convierte los ítems de una cotización al formato que espera el repositorio
  /// de reservas. Los servicios y las líneas libres se omiten: no hay stock
  /// detrás de ellos, y es lo que dice `TipoItemCotizacion.esReservable`.
  static List<ItemReservaDraft> mapearItems(
    List<ItemCotizacionEditor> cotItems,
  ) {
    return cotItems
        .where((i) => i.tipo.esReservable && i.referenciaId != null)
        .map(
          (i) => ItemReservaDraft(
            productoId: i.referenciaId!,
            cantidad: i.cantidad,
            precioUnitario: i.precioUnitario,
          ),
        )
        .toList();
  }

  /// Crea la reserva en BD. Devuelve `null` en éxito o un mensaje de error.
  Future<String?> ejecutar({
    required int clienteId,
    required int? motoId,
    required int cotizacionId,
    required int totalReserva,
    required List<ItemReservaDraft> items,
    required String fechaLimite,
    int abonoInicial = 0,
    String metodoPago = 'Efectivo',
    String? referencia,
  }) {
    return _ref.read(reservasProvider.notifier).crear(
          clienteId: clienteId,
          motoId: motoId,
          cotizacionId: cotizacionId,
          fechaLimite: fechaLimite,
          totalReserva: totalReserva,
          items: items,
          abonoInicial: abonoInicial,
          metodoPagoInicial: metodoPago,
          referenciaInicial: referencia,
        );
  }
}

final cotizarAReservaProvider = Provider<CotizarAReservaUseCase>(
  (ref) => CotizarAReservaUseCase(ref),
  name: 'cotizarAReservaProvider',
);
