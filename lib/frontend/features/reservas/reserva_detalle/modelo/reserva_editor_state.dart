import '../../../../../backend/features/reservas/enum/enum_reserva.dart';
import '../../../../../backend/features/reservas/modelo/reserva_abono.dart';
import '../../../../../backend/features/reservas/modelo/reserva_item.dart';
import '../../../../../backend/features/productos/repositorio/repositorio_producto.dart';

/// Qué se está haciendo en el panel izquierdo.
///
/// Son dos y no tres como en órdenes: una reserva solo aparta **productos**.
/// El segundo no es otra clase de línea sino la otra mitad del trabajo —el
/// dinero—, y por eso comparte sitio en vez de tener pantalla propia: apartar
/// y abonar son el mismo momento en el mostrador.
enum SeccionReserva {
  productos('Productos'),
  abonos('Abonos');

  const SeccionReserva(this.etiqueta);

  final String etiqueta;
}

/// En qué punto va el guardado automático.
enum EstadoGuardadoReserva { guardado, pendiente, guardando, bloqueado }

/// Todo lo que la pantalla del editor necesita para pintarse.
final class ReservaEditorState {
  const ReservaEditorState({
    required this.reservaId,
    required this.numero,
    required this.clienteNombre,
    required this.estado,
    required this.totalReserva,
    required this.pagadoAcumulado,
    this.motoDescripcion,
    this.motoPlaca,
    this.cotizacionId,
    this.fechaLimite,
    this.lineas = const [],
    this.abonos = const [],
    this.seccionActiva = SeccionReserva.productos,
    this.busquedaCatalogo = '',
    this.categoriaId,
    this.paginaCatalogo = 0,
    this.guardado = EstadoGuardadoReserva.guardado,
    this.motivoBloqueo,
  });

  /// Cuántos productos trae la rejilla del panel izquierdo.
  static const int tamanoPaginaCatalogo = 12;

  final int reservaId;
  final String numero;
  final String clienteNombre;
  final String? motoDescripcion;
  final String? motoPlaca;

  /// De qué cotización salió, si salió de alguna. Solo informativo: la
  /// cotización quedó congelada y esta reserva ya no le rinde cuentas.
  final int? cotizacionId;

  final EstadoReserva estado;
  final DateTime? fechaLimite;

  /// Los dos vienen de la base, no se calculan aquí: son cachés que el
  /// repositorio mantiene, y espejarlos en Dart era la forma de que se
  /// desviaran.
  final int totalReserva;
  final int pagadoAcumulado;

  /// Las líneas apartadas, tal como están en la base.
  final List<ReservaItem> lineas;

  /// Las entregas de dinero, de la más reciente a la más vieja. Las negativas
  /// son devoluciones.
  final List<ReservaAbono> abonos;

  final SeccionReserva seccionActiva;
  final String busquedaCatalogo;
  final int? categoriaId;
  final int paginaCatalogo;

  final EstadoGuardadoReserva guardado;
  final String? motivoBloqueo;

  /// Si todavía se le pueden mover líneas.
  ///
  /// Lo decide el mismo enum que usa el repositorio para rechazarlo, así que
  /// la interfaz y la garantía no pueden decir cosas distintas.
  bool get editable => estado.editable;

  int get saldo => (totalReserva - pagadoAcumulado).clamp(0, totalReserva);

  bool get pagada => totalReserva > 0 && pagadoAcumulado >= totalReserva;

  double get porcentajePagado =>
      totalReserva > 0 ? (pagadoAcumulado / totalReserva).clamp(0.0, 1.0) : 0.0;

  /// Cuánto se puede abonar todavía. Cero cierra el formulario de abonos.
  int get abonoMaximo => saldo;

  /// Traduce los filtros del panel a los que entiende el repositorio.
  ///
  /// `soloActivos` va fijo: un producto dado de baja no se aparta.
  FiltroProductos get filtroProductos => FiltroProductos(
        busqueda: busquedaCatalogo,
        categoriaId: categoriaId,
        soloActivos: true,
      );

  ReservaEditorState copyWith({
    String? numero,
    String? clienteNombre,
    String? motoDescripcion,
    String? motoPlaca,
    int? cotizacionId,
    EstadoReserva? estado,
    DateTime? fechaLimite,
    int? totalReserva,
    int? pagadoAcumulado,
    List<ReservaItem>? lineas,
    List<ReservaAbono>? abonos,
    SeccionReserva? seccionActiva,
    String? busquedaCatalogo,
    Object? categoriaId = _sinCambio,
    int? paginaCatalogo,
    EstadoGuardadoReserva? guardado,
    String? motivoBloqueo,
  }) =>
      ReservaEditorState(
        reservaId: reservaId,
        numero: numero ?? this.numero,
        clienteNombre: clienteNombre ?? this.clienteNombre,
        motoDescripcion: motoDescripcion ?? this.motoDescripcion,
        motoPlaca: motoPlaca ?? this.motoPlaca,
        cotizacionId: cotizacionId ?? this.cotizacionId,
        estado: estado ?? this.estado,
        fechaLimite: fechaLimite ?? this.fechaLimite,
        totalReserva: totalReserva ?? this.totalReserva,
        pagadoAcumulado: pagadoAcumulado ?? this.pagadoAcumulado,
        lineas: lineas ?? this.lineas,
        abonos: abonos ?? this.abonos,
        seccionActiva: seccionActiva ?? this.seccionActiva,
        busquedaCatalogo: busquedaCatalogo ?? this.busquedaCatalogo,
        categoriaId: identical(categoriaId, _sinCambio)
            ? this.categoriaId
            : categoriaId as int?,
        paginaCatalogo: paginaCatalogo ?? this.paginaCatalogo,
        guardado: guardado ?? this.guardado,
        motivoBloqueo: motivoBloqueo,
      );

  /// Centinela para distinguir "no tocar [categoriaId]" de "ponerlo en null"
  /// (= quitar el filtro), que con `??` serían lo mismo.
  static const Object _sinCambio = Object();

  /// Reemplaza una línea conservando el orden. Lo usa el cambio de cantidad,
  /// que actualiza la pantalla antes de escribir.
  ReservaEditorState conLinea(ReservaItem editada) => copyWith(
        lineas: [
          for (final l in lineas)
            if (l.id == editada.id) editada else l,
        ],
      );
}
