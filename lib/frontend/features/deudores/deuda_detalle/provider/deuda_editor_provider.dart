import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/deudores/enum/enum_deudor.dart';
import '../../../../../backend/features/deudores/modelo/deudor_pago.dart';
import '../../../../../backend/features/deudores/modelo/deudor_resumen.dart';
import '../../../../../backend/features/deudores/repositorio/repositorio_deudores.dart';
import '../../../../../backend/share/dominio/metodo_pago.dart';
import '../../../../../core/resultado.dart';
import '../../provider/deudores_providers.dart';

/// Lo que la ficha de una deuda necesita para pintarse.
///
/// Es el detalle del repositorio partido en dos —cabecera y pagos— porque son
/// las dos mitades que se reconstruyen por separado: anotar un abono cambia la
/// lista y las cuentas, pero no el cliente ni el concepto.
final class DeudaEditorState {
  const DeudaEditorState({required this.deuda, required this.pagos});

  final DeudorResumen deuda;
  final List<DeudorPago> pagos;

  int get saldo => deuda.saldo;
  int get montoTotal => deuda.montoTotal;
  int get montoPagado => deuda.montoPagado;
  double get porcentajePagado => deuda.porcentajePagado;

  /// Una deuda cerrada —cobrada o dada por perdida— se lee pero no se toca.
  /// No se le anotan pagos ni se le cambia el monto: si hubo un error, la
  /// corrección es reabrirla, no reescribir el pasado.
  bool get editable => deuda.estaViva;
}

/// La ficha de una deuda: sus datos, sus pagos y lo que se le puede hacer.
///
/// **No hay autoguardado, a diferencia del editor de reservas.** Una reserva
/// se arma línea a línea y cada tecleo es un cambio; una deuda es una cabecera
/// que se teclea una vez y después solo recibe abonos. Guardar solo cuando se
/// confirma el diálogo evita escribir la base a cada letra del concepto.
///
/// Tras cada escritura se **relee el detalle** en vez de parchear el estado en
/// memoria: el `monto_pagado` y el estado los recalcula el repositorio, y
/// adivinarlos aquí es la vía por la que la pantalla acaba diciendo algo
/// distinto de lo que hay guardado.
class DeudaEditorNotifier extends AsyncNotifier<DeudaEditorState> {
  DeudaEditorNotifier(this.deudaId);

  final int deudaId;

  /// `late` sin `final`: `build()` se repite y el campo se reasigna.
  late RepositorioDeudores _repo;

  @override
  Future<DeudaEditorState> build() async {
    _repo = ref.watch(repositorioDeudoresProvider);
    return _leer();
  }

  Future<DeudaEditorState> _leer() async {
    final detalle = await _repo.obtenerDetalle(deudaId);
    return DeudaEditorState(deuda: detalle.resumen, pagos: detalle.pagos);
  }

  /// Ejecuta la escritura y relee. El [Resultado] se devuelve tal cual: la
  /// vista decide si lo enseña como aviso o como texto en el diálogo.
  Future<Resultado> _escribirY(Future<Resultado> Function() operacion) async {
    final resultado = await operacion();
    if (resultado case Fallo()) return resultado;
    if (!ref.mounted) return resultado;
    state = AsyncData(await _leer());
    // Sin `invalidate` del listado: `observarPagina` y `observarResumen` son
    // streams de Drift y re-emiten solos en cuanto cambia la tabla.
    return resultado;
  }

  Future<Resultado> registrarPago({
    required int monto,
    required MetodoPago metodoPago,
    String? notas,
  }) =>
      _escribirY(() => _repo.registrarPago(
            deudorId: deudaId,
            monto: monto,
            metodoPago: metodoPago,
            notas: notas,
          ));

  Future<Resultado> eliminarPago(int pagoId) =>
      _escribirY(() => _repo.eliminarPago(pagoId, deudaId));

  Future<Resultado> actualizarDatos({
    required String concepto,
    required int montoTotal,
    DateTime? fechaVencimiento,
    String? notas,
  }) =>
      _escribirY(() => _repo.actualizar(
            id: deudaId,
            concepto: concepto,
            montoTotal: montoTotal,
            fechaVencimiento: fechaVencimiento,
            notas: notas,
          ));

  Future<Resultado> cambiarEstado(EstadoDeudor nuevo) =>
      _escribirY(() => _repo.cambiarEstado(deudaId, nuevo));
}

final deudaEditorProvider = AsyncNotifierProvider.autoDispose
    .family<DeudaEditorNotifier, DeudaEditorState, int>(
  DeudaEditorNotifier.new,
  name: 'deudaEditorProvider',
);
