import '../../../../../backend/features/deudores/enum/enum_deudor.dart';
import '../../../../../backend/features/deudores/modelo/deudor_item.dart';
import '../../../../../backend/features/deudores/modelo/deudor_pago.dart';
import '../../../../../backend/features/productos/repositorio/repositorio_producto.dart';

/// Qué se está haciendo en el panel izquierdo.
///
/// Son las mismas dos de una reserva: lo que se lleva y lo que paga. Comparten
/// sitio porque son el mismo momento en el mostrador —el cliente se lleva unos
/// repuestos y deja algo a cuenta— y porque la deuda de la derecha tiene que
/// verse en los dos casos.
enum SeccionDeuda {
  productos('Repuestos'),
  abonos('Abonos');

  const SeccionDeuda(this.etiqueta);

  final String etiqueta;
}

/// En qué punto va el guardado automático.
enum EstadoGuardadoDeuda { guardado, pendiente, guardando, bloqueado }

/// Todo lo que la ficha de una deuda necesita para pintarse.
final class DeudaEditorState {
  const DeudaEditorState({
    required this.deudaId,
    required this.numero,
    required this.clienteId,
    required this.clienteNombre,
    required this.estado,
    required this.montoTotal,
    required this.montoPagado,
    this.motoId,
    this.motoDescripcion,
    this.concepto,
    this.notas,
    this.fechaVencimiento,
    this.lineas = const [],
    this.pagos = const [],
    this.seccionActiva = SeccionDeuda.productos,
    this.busquedaCatalogo = '',
    this.categoriaId,
    this.paginaCatalogo = 0,
    this.guardado = EstadoGuardadoDeuda.guardado,
    this.motivoBloqueo,
  });

  /// Cuántos productos trae la rejilla del panel izquierdo.
  static const int tamanoPaginaCatalogo = 12;

  final int deudaId;
  final String numero;
  final int clienteId;
  final String clienteNombre;
  final int? motoId;
  final String? motoDescripcion;
  final String? concepto;
  final String? notas;
  final EstadoDeudor estado;
  final DateTime? fechaVencimiento;

  /// Los dos vienen de la base, no se calculan aquí: son cachés que el
  /// repositorio mantiene, y espejarlos en Dart era la forma de que se
  /// desviaran.
  final int montoTotal;
  final int montoPagado;

  /// Lo fiado, tal como está en la base.
  final List<DeudorItem> lineas;

  /// Los abonos, del más reciente al más viejo. Los negativos son
  /// devoluciones.
  final List<DeudorPago> pagos;

  final SeccionDeuda seccionActiva;
  final String busquedaCatalogo;
  final int? categoriaId;
  final int paginaCatalogo;

  final EstadoGuardadoDeuda guardado;
  final String? motivoBloqueo;

  /// Si todavía se le pueden mover líneas.
  ///
  /// Una deuda cobrada o dada por perdida se lee pero no se toca: cambiarle
  /// una línea movería stock de mercancía que salió del taller hace tiempo.
  /// Es la misma condición que aplica el repositorio para rechazarlo, así que
  /// la interfaz y la garantía no pueden decir cosas distintas.
  bool get editable =>
      estado == EstadoDeudor.activa || estado == EstadoDeudor.vencida;

  int get saldo => (montoTotal - montoPagado).clamp(0, montoTotal);

  bool get pagada => montoTotal > 0 && montoPagado >= montoTotal;

  double get porcentajePagado =>
      montoTotal > 0 ? (montoPagado / montoTotal).clamp(0.0, 1.0) : 0.0;

  /// Si el plazo ya se cumplió. Misma regla que `DeudorResumen.estaVencida`:
  /// la marca del usuario **más** el calendario.
  bool get estaVencida {
    if (!editable) return false;
    if (estado == EstadoDeudor.vencida) return true;
    final limite = fechaVencimiento;
    if (limite == null) return false;
    final hoy = DateTime.now();
    return limite.isBefore(DateTime(hoy.year, hoy.month, hoy.day));
  }

  /// Traduce los filtros del panel a los que entiende el repositorio.
  ///
  /// `soloActivos` va fijo: un producto dado de baja no se fía.
  FiltroProductos get filtroProductos => FiltroProductos(
        busqueda: busquedaCatalogo,
        categoriaId: categoriaId,
        soloActivos: true,
      );

  DeudaEditorState copyWith({
    String? numero,
    String? clienteNombre,
    Object? motoId = _sinCambio,
    Object? motoDescripcion = _sinCambio,
    Object? concepto = _sinCambio,
    Object? notas = _sinCambio,
    EstadoDeudor? estado,
    Object? fechaVencimiento = _sinCambio,
    int? montoTotal,
    int? montoPagado,
    List<DeudorItem>? lineas,
    List<DeudorPago>? pagos,
    SeccionDeuda? seccionActiva,
    String? busquedaCatalogo,
    Object? categoriaId = _sinCambio,
    int? paginaCatalogo,
    EstadoGuardadoDeuda? guardado,
    String? motivoBloqueo,
  }) =>
      DeudaEditorState(
        deudaId: deudaId,
        numero: numero ?? this.numero,
        clienteId: clienteId,
        clienteNombre: clienteNombre ?? this.clienteNombre,
        motoId: identical(motoId, _sinCambio) ? this.motoId : motoId as int?,
        motoDescripcion: identical(motoDescripcion, _sinCambio)
            ? this.motoDescripcion
            : motoDescripcion as String?,
        concepto: identical(concepto, _sinCambio)
            ? this.concepto
            : concepto as String?,
        notas: identical(notas, _sinCambio) ? this.notas : notas as String?,
        estado: estado ?? this.estado,
        fechaVencimiento: identical(fechaVencimiento, _sinCambio)
            ? this.fechaVencimiento
            : fechaVencimiento as DateTime?,
        montoTotal: montoTotal ?? this.montoTotal,
        montoPagado: montoPagado ?? this.montoPagado,
        lineas: lineas ?? this.lineas,
        pagos: pagos ?? this.pagos,
        seccionActiva: seccionActiva ?? this.seccionActiva,
        busquedaCatalogo: busquedaCatalogo ?? this.busquedaCatalogo,
        categoriaId: identical(categoriaId, _sinCambio)
            ? this.categoriaId
            : categoriaId as int?,
        paginaCatalogo: paginaCatalogo ?? this.paginaCatalogo,
        guardado: guardado ?? this.guardado,
        motivoBloqueo: motivoBloqueo,
      );

  /// Centinela para distinguir «no tocar el campo» de «ponerlo en null», que
  /// con `??` serían lo mismo. Aquí hacen falta varios: quitarle la moto o el
  /// plazo a una deuda es una operación real.
  static const Object _sinCambio = Object();

  /// Reemplaza una línea conservando el orden. Lo usa el cambio de cantidad,
  /// que actualiza la pantalla antes de escribir.
  DeudaEditorState conLinea(DeudorItem editada) => copyWith(
        lineas: [
          for (final l in lineas)
            if (l.id == editada.id) editada else l,
        ],
      );
}
