import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../../../../backend/features/ventas/facturas/repositorio/repositorio_facturas.dart';
import '../../../deudores/provider/deudores_provider.dart';
import '../../ordenes/provider/ordenes_providers.dart';
import 'facturas_providers.dart';
import 'facturas_state.dart';

class FacturasNotifier extends AsyncNotifier<FacturasState> {
  late final RepositorioFacturas _repo;

  @override
  Future<FacturasState> build() async {
    _repo = ref.watch(repositorioFacturasProvider);

    final sub = _repo.observarTodas().listen(
      (lista) {
        final actual = state.value;
        state = AsyncData(
          actual != null
              ? actual.copyWith(facturas: lista)
              : FacturasState(facturas: lista),
        );
      },
      onError: (Object e, StackTrace st) => state = AsyncError(e, st),
    );
    ref.onDispose(sub.cancel);

    final lista = await _repo.obtenerTodas();
    return FacturasState(facturas: lista);
  }

  // ── Filtros ────────────────────────────────────────────────────────────────

  void buscar(String query) {
    final actual = state.value;
    if (actual == null) return;
    state = AsyncData(actual.copyWith(filtroBusqueda: query.trim()));
  }

  void filtrarEstadoPago(EstadoPago? estado) {
    final actual = state.value;
    if (actual == null) return;
    state = AsyncData(actual.copyWith(filtroEstadoPago: estado));
  }

  // ── Factura CRUD ──────────────────────────────────────────────────────────

  Future<String?> crear({
    required TipoVenta  tipo,
    int?                ordenId,
    int?                clienteId,
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    double              iva       = 0,
    double              descuento = 0,
  }) async {
    try {
      await _repo.crear(
        tipo:       tipo,
        ordenId:    ordenId,
        clienteId:  clienteId,
        metodoPago: metodoPago,
        estadoPago: estadoPago,
        iva:        iva,
        descuento:  descuento,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> crearDesdeOrden({
    required int        ordenId,
    required int        clienteId,
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    double              iva = 0,
  }) async {
    try {
      await _repo.crearDesdeOrden(
        ordenId:    ordenId,
        clienteId:  clienteId,
        metodoPago: metodoPago,
        estadoPago: estadoPago,
        iva:        iva,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> actualizarDesdeOrden({
    required int        facturaId,
    required int        ordenId,
    int?                clienteId,
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    double              iva       = 0,
    double              descuento = 0,
  }) async {
    try {
      final factura = await _repo.actualizarDesdeOrden(
        facturaId:  facturaId,
        ordenId:    ordenId,
        clienteId:  clienteId,
        metodoPago: metodoPago,
        estadoPago: estadoPago,
        iva:        iva,
        descuento:  descuento,
      );
      ref.invalidate(facturaDetalleProvider(factura.id));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> actualizar({
    required int        id,
    required MetodoPago metodoPago,
    required EstadoPago estadoPago,
    double?             iva,
    double?             descuento,
    bool                actualizarCliente = false,
    int?                clienteId,
  }) async {
    try {
      final factura = await _repo.actualizar(
        id:                id,
        metodoPago:        metodoPago,
        estadoPago:        estadoPago,
        iva:               iva,
        descuento:         descuento,
        actualizarCliente: actualizarCliente,
        clienteId:         clienteId,
      );
      ref.invalidate(facturaDetalleProvider(id));
      // Si se cambió el cliente y hay una orden vinculada, refrescar su detalle
      if (actualizarCliente && factura.ordenId != null) {
        ref.invalidate(ordenDetalleProvider(factura.ordenId!));
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Registra el cobro de una factura: actualiza [totalPagado] y [estadoPago],
  /// y si el pago es parcial crea automáticamente una deuda vinculada.
  Future<String?> cobrar({
    required int         id,
    required double      totalPagado,
    required double      totalFactura,
    required EstadoPago  estadoPago,
    required MetodoPago  metodoPago,
    int?     clienteId,
    String?  concepto,
    String?  metodoPagoDeuda,
    String?  fechaVencimiento,
    String?  notasDeuda,
  }) async {
    try {
      final factura = await _repo.actualizarPago(
        id:          id,
        totalPagado: totalPagado,
        estadoPago:  estadoPago,
        metodoPago:  metodoPago,
      );
      ref.invalidate(facturaDetalleProvider(id));
      if (factura.ordenId != null) {
        ref.invalidate(ordenDetalleProvider(factura.ordenId!));
      }

      if (estadoPago == EstadoPago.pendiente &&
          concepto != null &&
          clienteId != null) {
        final montoDeuda = (totalFactura - totalPagado).round();
        if (montoDeuda > 0) {
          await ref.read(repositorioDeudoresProvider).crear(
            clienteId:         clienteId,
            ventaId:           id,
            concepto:          concepto,
            montoTotal:        montoDeuda,
            fechaVencimiento:  fechaVencimiento,
            notas:             notasDeuda,
            pagoInicial:       0,
            metodoPagoInicial: metodoPagoDeuda ?? 'Efectivo',
          );
        }
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> eliminar(int id) async {
    final actual = state.value;
    if (actual == null) return null;

    final snapshot = actual.facturas;
    state = AsyncData(
      actual.copyWith(
        facturas: snapshot.where((f) => f.id != id).toList(growable: false),
      ),
    );
    try {
      await _repo.eliminar(id);
      return null;
    } catch (e) {
      state = AsyncData(actual.copyWith(facturas: snapshot));
      return e.toString();
    }
  }

  // ── Items ─────────────────────────────────────────────────────────────────

  Future<String?> agregarItem({
    required int        ventaId,
    required TipoItem   tipoItem,
    int?                productoId,
    int?                servicioId,
    int?                tecnicoId,
    required String     descripcion,
    required double     cantidad,
    required double     precioUnitario,
    double              costoUnitario = 0,
  }) async {
    try {
      await _repo.agregarItem(
        ventaId:        ventaId,
        tipoItem:       tipoItem,
        productoId:     productoId,
        servicioId:     servicioId,
        tecnicoId:      tecnicoId,
        descripcion:    descripcion,
        cantidad:       cantidad,
        precioUnitario: precioUnitario,
        costoUnitario:  costoUnitario,
      );
      ref.invalidate(facturaDetalleProvider(ventaId));
      _invalidarOrdenSiExiste(ventaId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> actualizarItem(
    int itemId,
    int ventaId, {
    double? cantidad,
    double? precioUnitario,
  }) async {
    try {
      await _repo.actualizarItem(
        itemId,
        cantidad:       cantidad,
        precioUnitario: precioUnitario,
      );
      ref.invalidate(facturaDetalleProvider(ventaId));
      _invalidarOrdenSiExiste(ventaId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> eliminarItem(int itemId, int ventaId) async {
    try {
      await _repo.eliminarItem(itemId);
      ref.invalidate(facturaDetalleProvider(ventaId));
      _invalidarOrdenSiExiste(ventaId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  void _invalidarOrdenSiExiste(int ventaId) {
    final facturas = state.value?.facturas ?? const [];
    for (final f in facturas) {
      if (f.id == ventaId && f.ordenId != null) {
        ref.invalidate(ordenDetalleProvider(f.ordenId!));
        break;
      }
    }
  }
}
