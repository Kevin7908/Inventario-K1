import '../enum/enum_ordenes.dart';
import '../modelo/orden_detalle.dart';
import '../modelo/orden_resumen.dart';

/// Conteos de las cuatro tarjetas del encabezado, resueltos con un solo
/// `COUNT` por columna en vez de recorrer la lista en memoria (§5).
typedef ResumenOrdenes = ({
  int total,
  int enProceso,
  int pendientes,
  int completadas,
});

/// Criterios del listado, traducidos a un `WHERE` por el repositorio.
///
/// Value object con igualdad estructural: reabrir el stream con el mismo
/// filtro no cuenta como cambio y no dispara una consulta de más.
final class FiltroOrdenes {
  const FiltroOrdenes({this.busqueda = '', this.estado});

  /// Texto libre. Busca en el número de la orden, en el nombre del cliente y
  /// en la moto —marca, modelo, año y **placa**—: en un taller la moto se
  /// identifica por la placa antes que por el modelo.
  final String busqueda;

  /// `null` = todos los estados.
  final EstadoOrden? estado;

  @override
  bool operator ==(Object other) =>
      other is FiltroOrdenes &&
      other.busqueda == busqueda &&
      other.estado == estado;

  @override
  int get hashCode => Object.hash(busqueda, estado);
}

/// Un tramo del listado más el total real.
///
/// [total] cuenta **todas** las órdenes que cumplen el filtro, no las de la
/// página: es lo que necesita el paginador para saber cuántas hay.
final class PaginaOrdenes {
  const PaginaOrdenes({required this.items, required this.total});

  final List<OrdenResumen> items;
  final int total;

  static const vacia = PaginaOrdenes(items: [], total: 0);
}

abstract interface class RepositorioOrdenes {
  // Stream reactivo de la lista de órdenes (JOIN con motos y clientes).
  Stream<List<OrdenResumen>> observarTodas();

  /// Una página del listado. El `WHERE`, el `COUNT` y el `LIMIT` los resuelve
  /// SQLite (§5): antes el listado traía todas las órdenes y el recorte se
  /// hacía en Dart, así que cada tecla del buscador recorría el histórico
  /// entero del taller.
  ///
  /// [pagina] es de base cero.
  Stream<PaginaOrdenes> observarPagina({
    required FiltroOrdenes filtro,
    required int pagina,
    required int tamano,
  });

  // Future puntual para restaurar estado tras error.
  Future<List<OrdenResumen>> obtenerTodas();

  // Detalle completo: cabecera + tareas + repuestos.
  Future<OrdenDetalle> obtenerDetalle(int id);

  // Crea una nueva orden en estado ABIERTA.
  Future<OrdenResumen> agregar({
    required int motoId,
    required int clienteId,
    required int kilometrajeEntrada,
    String? diagnostico,
    String? observaciones,
  });

  // Actualiza estado, kilometraje, moto y/o diagnóstico.
  Future<OrdenResumen> actualizar({
    required int id,
    required EstadoOrden estado,
    required int kilometrajeEntrada,
    int? motoId,
    int? clienteId,
    String? diagnostico,
    String? observaciones,
  });

  /// Fija la rebaja de la orden, en pesos.
  ///
  /// Se recorta al subtotal de sus líneas: un descuento mayor dejaría el total
  /// en negativo. Aquí no hay `CHECK` que lo impida —el subtotal no es una
  /// columna, sino la suma de tres tablas— así que **este recorte es la única
  /// garantía**, y por eso tiene su test.
  Future<OrdenResumen> fijarDescuento({required int id, required int valor});

  /// Conteos del encabezado del listado, en una sola consulta.
  Stream<ResumenOrdenes> observarResumen();

  // Cargos (líneas libres)

  /// Agrega un cargo suelto: descripción y precio a mano, sin catálogo.
  ///
  /// No mueve inventario a propósito: si el repuesto estuviera dado de alta,
  /// sería un repuesto.
  Future<void> agregarCargo({
    required int ordenId,
    required String descripcion,
    required int precio,
  });

  Future<void> actualizarCargo(
    int cargoId, {
    String? descripcion,
    int? precio,
  });

  Future<void> eliminarCargo(int cargoId);

  // Elimina la orden y en cascada sus tareas y repuestos.
  Future<void> eliminar(int id);

  // Tareas 

  Future<void> agregarTarea({
    required int ordenId,
    required int servicioId,
    required int tecnicoId,
    required int precioPactado,
    String? notas,
  });

  Future<void> marcarTareaCompletada(int tareaId, {required bool completado});

  Future<void> actualizarTarea(
    int tareaId, {
    int? servicioId,
    int? tecnicoId,
    int? precioPactado,
    String? notas,
    bool? completado,
  });

  Future<void> eliminarTarea(int tareaId);

  // Repuestos

  Future<void> agregarRepuesto({
    required int ordenId,
    required int productoId,
    required double cantidad,
    required int precioUnitario,
  });

  // Elimina y re-inserta para que los triggers de stock actúen correctamente.
  Future<void> actualizarRepuesto(
    int repuestoId, {
    double? cantidad,
    int? precioUnitario,
  });

  Future<void> eliminarRepuesto(int repuestoId);

  // Reportes

  /// Cuántas órdenes distintas tiene asignadas cada técnico, indexado por
  /// id de técnico. Cuenta una vez por orden aunque el técnico tenga varias
  /// tareas ahí.
  Stream<Map<int, int>> observarConteoTareasPorTecnico();
}