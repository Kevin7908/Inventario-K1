import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/backend/features/cotizaciones/enum/enum_cotizacion.dart';
import 'package:inventario_k1/backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import 'package:inventario_k1/backend/features/cotizaciones/repositorio/repositorio_cotizaciones.dart';
import 'package:inventario_k1/backend/features/motos/modelo/moto.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/frontend/features/cotizaciones/provider/cotizaciones_provider.dart';
import 'package:inventario_k1/frontend/features/cotizaciones/widgets/dialogo/dialogo_cot_items_tabla.dart';
import 'package:inventario_k1/frontend/features/productos/provider/productos_provider.dart';
import '../../../../../core/iva_app.dart';

// ── Estado ────────────────────────────────────────────────────────────────────

final class CotizacionEditorState {
  const CotizacionEditorState({
    this.cotizacionId,
    this.cotizacionOriginal,
    this.moto,
    this.nombreCliente = '',
    this.telefono = '',
    this.items = const [],
    this.guardando = false,
    this.cargandoItems = false,
    this.busquedaProductos = '',
  });

  final int? cotizacionId;

  /// Snapshot de la cotización en BD; fallback de clienteId/motoId cuando el
  /// usuario no modifica la moto en modo edición.
  final CotizacionResumen? cotizacionOriginal;

  final Moto? moto;
  final String nombreCliente;
  final String telefono;
  final List<CotItemDraft> items;
  final bool guardando;
  final bool cargandoItems;
  final String busquedaProductos;

  bool get esEdicion => cotizacionId != null;

  // ── Totales ─────────────────────────────────────────────────────────────────

  int get subtotal => items.fold(0, (s, i) => s + i.subtotal);
  int get iva => ivaDe(subtotal);
  int get total => subtotal + iva;

  // ── Helpers de stock para la UI ─────────────────────────────────────────────

  int cantidadEnCarrito(int productId) => items
      .where((i) => i.referenciaId == productId)
      .fold(0, (s, i) => s + i.cantidad.toInt());

  int stockDisponible(Producto p) =>
      (p.stockActual.toInt() - cantidadEnCarrito(p.id ?? -1)).clamp(0, 999999);

  // ── Filtrado de productos ───────────────────────────────────────────────────

  List<Producto> filtrarProductos(List<Producto> todos) {
    if (busquedaProductos.isEmpty) return todos;
    final q = busquedaProductos.toLowerCase();
    return todos
        .where(
          (p) =>
              p.nombre.toLowerCase().contains(q) ||
              p.sku.toLowerCase().contains(q) ||
              (p.categoriaNombre?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  // ── copyWith ────────────────────────────────────────────────────────────────

  CotizacionEditorState copyWith({
    int? cotizacionId,
    Object? cotizacionOriginal = _sentinel,
    Object? moto = _sentinel,
    String? nombreCliente,
    String? telefono,
    List<CotItemDraft>? items,
    bool? guardando,
    bool? cargandoItems,
    String? busquedaProductos,
  }) {
    return CotizacionEditorState(
      cotizacionId: cotizacionId ?? this.cotizacionId,
      cotizacionOriginal: cotizacionOriginal == _sentinel
          ? this.cotizacionOriginal
          : cotizacionOriginal as CotizacionResumen?,
      moto: moto == _sentinel ? this.moto : moto as Moto?,
      nombreCliente: nombreCliente ?? this.nombreCliente,
      telefono: telefono ?? this.telefono,
      items: items ?? this.items,
      guardando: guardando ?? this.guardando,
      cargandoItems: cargandoItems ?? this.cargandoItems,
      busquedaProductos: busquedaProductos ?? this.busquedaProductos,
    );
  }

  static const Object _sentinel = Object();
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class CotizacionEditorNotifier extends Notifier<CotizacionEditorState> {
  @override
  CotizacionEditorState build() => const CotizacionEditorState();

  // ── Inicialización ──────────────────────────────────────────────────────────

  /// Llamar una vez desde addPostFrameCallback en el widget.
  /// No hace nada si [cotizacion] es null (modo nueva).
  void inicializar(CotizacionResumen? cotizacion) {
    if (cotizacion == null) return;
    state = state.copyWith(
      cotizacionId: cotizacion.id,
      cotizacionOriginal: cotizacion,
      nombreCliente: cotizacion.nombreCliente,
      telefono: cotizacion.telefonoCliente ?? '',
      cargandoItems: true,
    );
    _preCargarDatos(cotizacion);
  }

  Future<void> _preCargarDatos(CotizacionResumen cot) async {
    try {
      final motos = await ref.read(motosParaCotizacionProvider.future);
      final moto = motos.where((m) => m.id == cot.motoId).firstOrNull;

      final detalle =
          await ref.read(repositorioCotizacionesProvider).obtenerDetalle(cot.id);

      final items = detalle.items
          .map(
            (item) => CotItemDraft(
              tipo: item.tipoItem,
              referenciaId: item.referenciaId,
              descripcion: item.descripcion,
              cantidad: item.cantidad,
              precioUnitario: item.precioUnitario,
            ),
          )
          .toList();

      state = state.copyWith(moto: moto, items: items, cargandoItems: false);
    } catch (_) {
      state = state.copyWith(cargandoItems: false);
    }
  }

  // ── Formulario ──────────────────────────────────────────────────────────────

  void seleccionarMoto(Moto? moto) {
    if (moto == null) return;
    final clientes = ref.read(clientesParaCotizacionProvider).value ?? [];
    final cliente = clientes.where((c) => c.id == moto.clienteId).firstOrNull;
    state = state.copyWith(
      moto: moto,
      nombreCliente: moto.nombreCliente ?? '',
      telefono: cliente?.telefono ?? '',
    );
  }

  void buscarProductos(String q) =>
      state = state.copyWith(busquedaProductos: q.trim());

  // ── Carrito ─────────────────────────────────────────────────────────────────

  /// Retorna un mensaje de error si el producto no puede agregarse, o null si puede.
  String? validarAgregarProducto(Producto p) {
    if (p.stockActual <= 0) {
      return '"${p.nombre}" no tiene stock disponible.';
    }
    final yaEsta = state.cantidadEnCarrito(p.id ?? -1) > 0;
    final disponible =
        yaEsta ? p.stockActual.toInt() : state.stockDisponible(p);
    if (disponible <= 0) {
      return 'Ya tienes todo el stock de "${p.nombre}" en el carrito.';
    }
    return null;
  }

  /// Datos para construir el diálogo de cantidad.
  /// Precondición: [validarAgregarProducto] retornó null.
  ({int disponible, int cantidadInicial, bool esActualizacion})
      datosDialogoProducto(Producto p) {
    final enCarrito = state.cantidadEnCarrito(p.id ?? -1);
    final yaEsta = enCarrito > 0;
    final disponible =
        yaEsta ? p.stockActual.toInt() : state.stockDisponible(p);
    return (
      disponible: disponible,
      cantidadInicial: yaEsta ? enCarrito : 1,
      esActualizacion: yaEsta,
    );
  }

  void confirmarAgregarProducto(Producto p, int cantidad) {
    final items = List<CotItemDraft>.from(state.items);
    final idx = items.indexWhere((i) => i.referenciaId == p.id);
    if (idx >= 0) {
      final old = items[idx];
      items[idx] = CotItemDraft(
        tipo: old.tipo,
        referenciaId: old.referenciaId,
        descripcion: old.descripcion,
        cantidad: cantidad.toDouble(),
        precioUnitario: old.precioUnitario,
      );
    } else {
      items.add(CotItemDraft(
        tipo: TipoItemCotizacion.producto,
        referenciaId: p.id,
        descripcion: p.nombre,
        cantidad: cantidad.toDouble(),
        precioUnitario: p.precioVenta.round(),
      ));
    }
    state = state.copyWith(items: items);
  }

  void eliminarItem(int index) {
    final items = List<CotItemDraft>.from(state.items)..removeAt(index);
    state = state.copyWith(items: items);
  }

  // ── Catálogo ─────────────────────────────────────────────────────────────────

  Future<String?> eliminarProductoCatalogo(Producto p) async {
    if (p.id == null) return null;
    try {
      await ref.read(repositorioProductosProvider).eliminar(p.id!);
      final items =
          state.items.where((i) => i.referenciaId != p.id).toList();
      state = state.copyWith(items: items);
      ref.invalidate(productosParaCotizacionProvider);
      return null;
    } catch (e) {
      return 'No se pudo eliminar: $e';
    }
  }

  // ── Persistencia ─────────────────────────────────────────────────────────────

  /// Guarda (crea o actualiza) la cotización con ajuste de stock atómico.
  /// Retorna null en éxito o un mensaje de error si falla.
  Future<String?> guardar({
    required String vigencia,
    required String? notas,
  }) async {
    if (!state.esEdicion && state.moto == null) {
      return 'Selecciona una moto para continuar.';
    }
    if (vigencia.isEmpty) {
      return 'Ingresa la fecha de vigencia.';
    }

    state = state.copyWith(guardando: true);
    final itemsDraft = state.items.map((i) => i.toItemDraft()).toList();

    return state.esEdicion
        ? await _actualizar(vigencia: vigencia, notas: notas, itemsDraft: itemsDraft)
        : await _crear(vigencia: vigencia, notas: notas, itemsDraft: itemsDraft);
  }

  Future<String?> _crear({
    required String vigencia,
    required String? notas,
    required List<ItemDraft> itemsDraft,
  }) async {
    try {
      // El repositorio inserta cotización, ítems y descuenta stock en una
      // sola transacción SQLite.
      final nuevoId = await ref.read(repositorioCotizacionesProvider).crear(
            clienteId: state.moto!.clienteId,
            motoId: state.moto!.id,
            vigenciaHasta: vigencia,
            notas: notas,
            items: itemsDraft,
          );
      ref.invalidate(productosParaCotizacionProvider);
      state = state.copyWith(cotizacionId: nuevoId, guardando: false);
      return null;
    } catch (e) {
      state = state.copyWith(guardando: false);
      return 'Error al crear: $e';
    }
  }

  Future<String?> _actualizar({
    required String vigencia,
    required String? notas,
    required List<ItemDraft> itemsDraft,
  }) async {
    // El repositorio restaura el stock anterior, actualiza la cotización y
    // descuenta el stock nuevo, todo en una sola transacción SQLite.
    final error = await ref.read(cotizacionesProvider.notifier).actualizar(
          id: state.cotizacionId!,
          clienteId:
              state.moto?.clienteId ?? state.cotizacionOriginal?.clienteId,
          motoId: state.moto?.id ?? state.cotizacionOriginal?.motoId,
          vigenciaHasta: vigencia,
          notas: notas,
          items: itemsDraft,
        );
    if (error != null) {
      state = state.copyWith(guardando: false);
      return error;
    }
    ref.invalidate(productosParaCotizacionProvider);
    state = state.copyWith(guardando: false);
    return null;
  }
}

// ── Provider público ──────────────────────────────────────────────────────────

final cotizacionEditorProvider =
    NotifierProvider.autoDispose<CotizacionEditorNotifier, CotizacionEditorState>(
  CotizacionEditorNotifier.new,
  name: 'cotizacionEditorProvider',
);
