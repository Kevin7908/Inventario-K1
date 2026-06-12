import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/backend/features/motos/modelo/moto.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/features/reservas/repositorio/repositorio_reservas.dart';
import 'package:inventario_k1/frontend/features/reservas/provider/reservas_provider.dart';

import '../../../../../backend/features/reservas/modelo/reserva_resumen.dart';

final class ReservaItemDraft {
  const ReservaItemDraft({
    required this.productoId,
    required this.nombreProducto,
    required this.sku,
    required this.cantidad,
    required this.precioUnitario,
  });

  final int productoId;
  final String nombreProducto;
  final String sku;
  final double cantidad;
  final int precioUnitario;

  int get subtotal => (cantidad * precioUnitario).round();

  ReservaItemDraft conCantidad(double nueva) => ReservaItemDraft(
        productoId: productoId,
        nombreProducto: nombreProducto,
        sku: sku,
        cantidad: nueva,
        precioUnitario: precioUnitario,
      );

  ItemReservaDraft toItemDraft() => ItemReservaDraft(
        productoId: productoId,
        cantidad: cantidad,
        precioUnitario: precioUnitario,
      );
}

// ── Estado ────────────────────────────────────────────────────────────────────

final class ReservaEditorState {
  const ReservaEditorState({
    this.reservaId,
    this.reservaOriginal,
    this.moto,
    this.fechaLimite = '',
    this.items = const [],
    this.abonoInicial = 0,
    this.metodoPago = 'Efectivo',
    this.referenciaPago = '',
    this.busquedaProductos = '',
    this.paginaProductos = 0,
    this.guardando = false,
  });

  final int? reservaId;
  final ReservaResumen? reservaOriginal;
  final Moto? moto;
  final String fechaLimite;
  final List<ReservaItemDraft> items;
  final int abonoInicial;
  final String metodoPago;
  final String referenciaPago;
  final String busquedaProductos;
  final int paginaProductos;
  final bool guardando;

  static const int productosPorPagina = 21;

  bool get esEdicion => reservaId != null;

  int get total => items.fold(0, (s, i) => s + i.subtotal);

  int get saldo => (total - abonoInicial).clamp(0, total);

  int cantidadEnCarrito(int productoId) {
    final item = items.where((i) => i.productoId == productoId).firstOrNull;
    return item?.cantidad.toInt() ?? 0;
  }

  List<Producto> filtrarProductos(List<Producto> todos) {
    var lista = todos;
    if (busquedaProductos.isNotEmpty) {
      final q = busquedaProductos.toLowerCase();
      lista = lista
          .where(
            (p) =>
                p.nombre.toLowerCase().contains(q) ||
                p.sku.toLowerCase().contains(q),
          )
          .toList();
    }
    return lista;
  }

  List<Producto> paginaDeProductos(List<Producto> filtrados) {
    final inicio = paginaProductos * productosPorPagina;
    if (inicio >= filtrados.length) return const [];
    final fin = (inicio + productosPorPagina).clamp(0, filtrados.length);
    return filtrados.sublist(inicio, fin);
  }

  int totalPaginasProductos(List<Producto> filtrados) =>
      (filtrados.length / productosPorPagina).ceil().clamp(1, 9999);

  ReservaEditorState copyWith({
    int? reservaId,
    Object? reservaOriginal = _sentinel,
    Object? moto = _sentinel,
    String? fechaLimite,
    List<ReservaItemDraft>? items,
    int? abonoInicial,
    String? metodoPago,
    String? referenciaPago,
    String? busquedaProductos,
    int? paginaProductos,
    bool? guardando,
  }) {
    return ReservaEditorState(
      reservaId: reservaId ?? this.reservaId,
      reservaOriginal: reservaOriginal == _sentinel
          ? this.reservaOriginal
          : reservaOriginal as ReservaResumen?,
      moto: moto == _sentinel ? this.moto : moto as Moto?,
      fechaLimite: fechaLimite ?? this.fechaLimite,
      items: items ?? this.items,
      abonoInicial: abonoInicial ?? this.abonoInicial,
      metodoPago: metodoPago ?? this.metodoPago,
      referenciaPago: referenciaPago ?? this.referenciaPago,
      busquedaProductos: busquedaProductos ?? this.busquedaProductos,
      paginaProductos: paginaProductos ?? this.paginaProductos,
      guardando: guardando ?? this.guardando,
    );
  }

  static const Object _sentinel = Object();
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ReservaEditorNotifier extends Notifier<ReservaEditorState> {
  @override
  ReservaEditorState build() => const ReservaEditorState();

  // ── Inicialización ────────────────────────────────────────────────────────

  void inicializar(ReservaResumen? reserva) {
    if (reserva == null) return;
    state = state.copyWith(
      reservaId: reserva.id,
      reservaOriginal: reserva,
      fechaLimite: reserva.fechaLimite ?? '',
    );
    _preCargarItems(reserva);
  }

  Future<void> _preCargarItems(ReservaResumen reserva) async {
    try {
      final detalle = await ref
          .read(repositorioReservasProvider)
          .obtenerDetalle(reserva.id);

      final motos = ref.read(motosParaReservaProvider).value ?? const [];
      final moto = motos.where((m) => m.id == reserva.motoId).firstOrNull;

      final items = detalle.items
          .map((it) => ReservaItemDraft(
                productoId: it.productoId,
                nombreProducto: it.nombreProducto,
                sku: it.sku,
                cantidad: it.cantidad,
                precioUnitario: it.precioUnitario,
              ))
          .toList();

      state = state.copyWith(moto: moto, items: items);
    } catch (_) {}
  }

  // ── Formulario ─────────────────────────────────────────────────────────────

  void seleccionarMoto(Moto moto) {
    state = state.copyWith(moto: moto);
  }

  void cambiarFecha(String fecha) {
    state = state.copyWith(fechaLimite: fecha);
  }

  void buscarProductos(String q) {
    state = state.copyWith(busquedaProductos: q.trim(), paginaProductos: 0);
  }

  void cambiarPaginaProductos(int pagina) {
    state = state.copyWith(paginaProductos: pagina);
  }

  void cambiarAbonoInicial(int monto) {
    state = state.copyWith(abonoInicial: monto.clamp(0, state.total));
  }

  void cambiarMetodoPago(String metodo) {
    state = state.copyWith(metodoPago: metodo);
  }

  void cambiarReferencia(String ref) {
    state = state.copyWith(referenciaPago: ref);
  }

  // ── Carrito ───────────────────────────────────────────────────────────────

  void toggleProducto(Producto p) {
    final items = List<ReservaItemDraft>.from(state.items);
    final idx = items.indexWhere((i) => i.productoId == p.id);
    if (idx >= 0) items.removeAt(idx);
    state = state.copyWith(items: items);
  }

  void agregarProductoConCantidad(Producto p, double cantidad) {
    if (cantidad <= 0 || p.id == null) return;
    final items = List<ReservaItemDraft>.from(state.items);
    final idx = items.indexWhere((i) => i.productoId == p.id);
    final draft = ReservaItemDraft(
      productoId: p.id!,
      nombreProducto: p.nombre,
      sku: p.sku,
      cantidad: cantidad,
      precioUnitario: p.precioVenta.round(),
    );
    if (idx >= 0) {
      items[idx] = draft;
    } else {
      items.add(draft);
    }
    state = state.copyWith(items: items);
  }

  void cambiarCantidad(int productoId, double cantidad) {
    if (cantidad <= 0) {
      eliminarItem(productoId);
      return;
    }
    final items = state.items.map((i) {
      return i.productoId == productoId ? i.conCantidad(cantidad) : i;
    }).toList();
    state = state.copyWith(items: items);
  }

  void eliminarItem(int productoId) {
    final items =
        state.items.where((i) => i.productoId != productoId).toList();
    state = state.copyWith(items: items);
  }

  // ── Guardar ───────────────────────────────────────────────────────────────

  String? validar() {
    if (state.moto == null && !state.esEdicion) {
      return 'Selecciona una moto para continuar.';
    }
    if (state.fechaLimite.isEmpty) {
      return 'Ingresa la fecha límite de la reserva.';
    }
    if (state.items.isEmpty) {
      return 'Agrega al menos un producto a la reserva.';
    }
    return null;
  }

  Future<String?> guardar() async {
    final error = validar();
    if (error != null) return error;

    state = state.copyWith(guardando: true);
    final itemsDraft = state.items.map((i) => i.toItemDraft()).toList();

    return state.esEdicion
        ? await _actualizar(itemsDraft)
        : await _crear(itemsDraft);
  }

  Future<String?> _crear(List<ItemReservaDraft> items) async {
    try {
      final error = await ref.read(reservasProvider.notifier).crear(
            clienteId: state.moto!.clienteId,
            motoId: state.moto!.id,
            fechaLimite: state.fechaLimite,
            totalReserva: state.total,
            items: items,
            abonoInicial: state.abonoInicial,
            metodoPagoInicial: state.metodoPago,
            referenciaInicial: state.referenciaPago.isEmpty
                ? null
                : state.referenciaPago,
          );
      ref.invalidate(productosParaReservaProvider);
      state = state.copyWith(guardando: false);
      return error;
    } catch (e) {
      state = state.copyWith(guardando: false);
      return e.toString();
    }
  }

  Future<String?> _actualizar(List<ItemReservaDraft> items) async {
    try {
      final error = await ref.read(reservasProvider.notifier).actualizar(
            id: state.reservaId!,
            motoId: state.moto?.id ?? state.reservaOriginal?.motoId,
            cotizacionId: state.reservaOriginal?.cotizacionId,
            fechaLimite: state.fechaLimite,
            totalReserva: state.total,
            items: items,
          );
      ref.invalidate(productosParaReservaProvider);
      state = state.copyWith(guardando: false);
      return error;
    } catch (e) {
      state = state.copyWith(guardando: false);
      return e.toString();
    }
  }
}

// ── Provider público ──────────────────────────────────────────────────────────

final reservaEditorProvider =
    NotifierProvider.autoDispose<ReservaEditorNotifier, ReservaEditorState>(
  ReservaEditorNotifier.new,
  name: 'reservaEditorProvider',
);
