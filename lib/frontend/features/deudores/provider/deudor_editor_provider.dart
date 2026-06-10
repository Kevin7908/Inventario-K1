import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/backend/features/deudores/enum/enum_deudor.dart';
import 'package:inventario_k1/backend/features/deudores/modelo/deudor_resumen.dart';

import 'deudores_provider.dart';

// ── Estado ────────────────────────────────────────────────────────────────────

final class DeudorEditorState {
  const DeudorEditorState({
    this.deudorId,
    this.clienteId,
    this.clienteNombre = '',
    this.ventaId,
    this.concepto = '',
    this.montoTotal = 0,
    this.fechaVencimiento,
    this.notas = '',
    this.estado = EstadoDeudor.activa,
    this.pagoInicial = 0,
    this.metodoPagoInicial = 'Efectivo',
    this.notasPagoInicial = '',
    this.guardando = false,
  });

  final int? deudorId;
  final int? clienteId;
  final String clienteNombre;
  final int? ventaId;
  final String concepto;
  final int montoTotal;
  final String? fechaVencimiento;
  final String notas;
  final EstadoDeudor estado;
  final int pagoInicial;
  final String metodoPagoInicial;
  final String notasPagoInicial;
  final bool guardando;

  bool get esEdicion => deudorId != null;

  int get saldo => (montoTotal - pagoInicial).clamp(0, montoTotal);

  DeudorEditorState copyWith({
    Object? deudorId = _sentinel,
    Object? clienteId = _sentinel,
    String? clienteNombre,
    Object? ventaId = _sentinel,
    String? concepto,
    int? montoTotal,
    Object? fechaVencimiento = _sentinel,
    String? notas,
    EstadoDeudor? estado,
    int? pagoInicial,
    String? metodoPagoInicial,
    String? notasPagoInicial,
    bool? guardando,
  }) {
    return DeudorEditorState(
      deudorId: deudorId == _sentinel ? this.deudorId : deudorId as int?,
      clienteId: clienteId == _sentinel ? this.clienteId : clienteId as int?,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      ventaId: ventaId == _sentinel ? this.ventaId : ventaId as int?,
      concepto: concepto ?? this.concepto,
      montoTotal: montoTotal ?? this.montoTotal,
      fechaVencimiento: fechaVencimiento == _sentinel
          ? this.fechaVencimiento
          : fechaVencimiento as String?,
      notas: notas ?? this.notas,
      estado: estado ?? this.estado,
      pagoInicial: pagoInicial ?? this.pagoInicial,
      metodoPagoInicial: metodoPagoInicial ?? this.metodoPagoInicial,
      notasPagoInicial: notasPagoInicial ?? this.notasPagoInicial,
      guardando: guardando ?? this.guardando,
    );
  }

  static const Object _sentinel = Object();
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class DeudorEditorNotifier extends Notifier<DeudorEditorState> {
  @override
  DeudorEditorState build() => const DeudorEditorState();

  void inicializar(DeudorResumen? resumen) {
    if (resumen == null) {
      state = const DeudorEditorState();
      return;
    }
    state = DeudorEditorState(
      deudorId: resumen.id,
      clienteId: resumen.clienteId,
      clienteNombre: resumen.nombreCliente,
      ventaId: resumen.ventaId,
      concepto: resumen.concepto,
      montoTotal: resumen.montoTotal,
      fechaVencimiento: resumen.fechaVencimiento,
      notas: resumen.notas ?? '',
      estado: resumen.estado,
    );
  }

  void setCliente(int id, String nombre) {
    state = state.copyWith(clienteId: id, clienteNombre: nombre);
  }

  void setVentaId(int? id) => state = state.copyWith(ventaId: id);
  void setConcepto(String v) => state = state.copyWith(concepto: v);
  void setMontoTotal(int v) => state = state.copyWith(montoTotal: v);
  void setFechaVencimiento(String? v) =>
      state = state.copyWith(fechaVencimiento: v);
  void setNotas(String v) => state = state.copyWith(notas: v);
  void setEstado(EstadoDeudor v) => state = state.copyWith(estado: v);
  void setPagoInicial(int v) => state = state.copyWith(pagoInicial: v);
  void setMetodoPagoInicial(String v) =>
      state = state.copyWith(metodoPagoInicial: v);
  void setNotasPagoInicial(String v) =>
      state = state.copyWith(notasPagoInicial: v);

  String? _validar() {
    if (state.clienteId == null) return 'Selecciona un cliente.';
    if (state.montoTotal <= 0) return 'El monto debe ser mayor a 0.';
    return null;
  }

  Future<String?> guardar() async {
    final error = _validar();
    if (error != null) return error;

    state = state.copyWith(guardando: true);
    try {
      final notifier = ref.read(deudoresProvider.notifier);
      String? resultado;

      if (state.esEdicion) {
        resultado = await notifier.actualizar(
          id: state.deudorId!,
          ventaId: state.ventaId,
          concepto: state.concepto.trim(),
          montoTotal: state.montoTotal,
          fechaVencimiento: state.fechaVencimiento,
          notas: state.notas.trim().isEmpty ? null : state.notas.trim(),
          estado: state.estado,
        );
      } else {
        resultado = await notifier.crear(
          clienteId: state.clienteId!,
          ventaId: state.ventaId,
          concepto: state.concepto.trim(),
          montoTotal: state.montoTotal,
          fechaVencimiento: state.fechaVencimiento,
          notas: state.notas.trim().isEmpty ? null : state.notas.trim(),
          pagoInicial: state.pagoInicial,
          metodoPagoInicial: state.metodoPagoInicial,
          notasPagoInicial: state.notasPagoInicial.trim().isEmpty
              ? null
              : state.notasPagoInicial.trim(),
        );
      }
      return resultado;
    } finally {
      state = state.copyWith(guardando: false);
    }
  }
}

// ── Provider público ──────────────────────────────────────────────────────────

final deudorEditorProvider =
    NotifierProvider<DeudorEditorNotifier, DeudorEditorState>(
  DeudorEditorNotifier.new,
  name: 'deudorEditorProvider',
);
