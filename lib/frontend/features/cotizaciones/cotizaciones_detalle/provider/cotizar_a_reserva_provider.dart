import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/backend/features/cotizaciones/enum/enum_cotizacion.dart';
import 'package:inventario_k1/backend/features/reservas/repositorio/repositorio_reservas.dart';
import 'package:inventario_k1/frontend/features/cotizaciones/widgets/dialogo/dialogo_cot_items_tabla.dart';
import 'package:inventario_k1/frontend/features/reservas/provider/reservas_provider.dart';

/// Use-case de responsabilidad única: convertir una cotización guardada en reserva.
///
/// Mapea [CotItemDraft] → [ItemReservaDraft] (solo ítems tipo PRODUCTO)
/// y delega la creación al [reservasProvider].
final class CotizarAReservaUseCase {
  const CotizarAReservaUseCase(this._ref);

  final Ref _ref;

  /// Convierte los ítems de una cotización al formato que espera el repositorio
  /// de reservas. Los servicios se omiten porque no tienen stock reservable.
  static List<ItemReservaDraft> mapearItems(List<CotItemDraft> cotItems) {
    return cotItems
        .where(
          (i) =>
              i.tipo == TipoItemCotizacion.producto && i.referenciaId != null,
        )
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
