import '../../../../../backend/share/dominio/metodo_pago.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/backend/features/reservas/repositorio/repositorio_reservas.dart';
import 'package:inventario_k1/frontend/features/reservas/provider/reservas_providers.dart';

import '../modelo/item_cotizacion_editor.dart';

/// Use-case de responsabilidad única: convertir una cotización guardada en
/// reserva.
///
/// Mapea [ItemCotizacionEditor] → [ItemReservaDraft] (solo ítems reservables)
/// y delega la creación al repositorio.
///
/// **Una cotización se reserva una sola vez.** La columna `cotizacion_id` es
/// `UNIQUE`, así que un segundo intento lo rechazaría la base con un error
/// ilegible; esto lo comprueba antes para poder decir cuál es la reserva que
/// ya existe. Sin eso, dos clics seguidos en «Reservar» descontaban el stock
/// dos veces.
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
  ///
  /// Sigue devolviendo `String?` y no `Resultado` porque el diálogo que la
  /// llama es de los que quedan por migrar; se cambia al tocarlo.
  Future<String?> ejecutar({
    required int clienteId,
    required int? motoId,
    required int cotizacionId,
    required int totalReserva,
    required List<ItemReservaDraft> items,
    required DateTime? fechaLimite,
    int abonoInicial = 0,
    MetodoPago metodoPago = MetodoPago.efectivo,
    String? referencia,
  }) async {
    final repositorio = _ref.read(repositorioReservasProvider);

    final yaExiste = await repositorio.reservaDeCotizacion(cotizacionId);
    if (yaExiste != null) {
      return 'Esta cotización ya se reservó. Ábrela desde Reservas para '
          'modificarla.';
    }

    try {
      await repositorio.crear(
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
      _ref.invalidate(reservasListaProvider);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }
}

final cotizarAReservaProvider = Provider<CotizarAReservaUseCase>(
  (ref) => CotizarAReservaUseCase(ref),
  name: 'cotizarAReservaProvider',
);
