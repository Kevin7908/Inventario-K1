import '../../../../../backend/features/ordenes/enum/enum_ordenes.dart';
import '../../../../../backend/features/ordenes/repositorio/repositorio_ordenes.dart';
import '../modelo/linea_orden_editor.dart';

/// Escribe la orden en la base, **una línea a la vez**.
///
/// Vive aparte del notifier por la misma razón que `GuardadoCotizacion`:
/// **cuándo** guardar —el retardo, el estado de la barra, qué hacer si falla—
/// es del notifier; **cómo** se escribe es de aquí.
///
/// La diferencia con cotizaciones es el fondo del asunto. Aquel guarda con
/// `actualizar`, que por dentro **borra todas las líneas y las reinserta**.
/// Aquí eso es imposible por dos motivos:
///
/// - `ordenes_tareas.id` es la identidad de una tarea. Borrarla y reinsertarla
///   le cambia el id en cada tecleo, y con él se pierde `completado`.
/// - `agregarRepuesto` descuenta stock al instante: un `DELETE + INSERT` de
///   todas las líneas escribiría un par de movimientos de inventario **por
///   cada tecla**. Es justo la basura que el retardo del notifier evita.
///
/// Por eso cada operación es su propia llamada al repositorio, y cada una es
/// ya una transacción allá dentro.
class GuardadoOrden {
  const GuardadoOrden(this._repo);

  final RepositorioOrdenes _repo;

  // Alta de líneas

  Future<void> agregarServicio({
    required int ordenId,
    required int servicioId,
    required int tecnicoId,
    required int precio,
  }) =>
      _repo.agregarTarea(
        ordenId: ordenId,
        servicioId: servicioId,
        tecnicoId: tecnicoId,
        precioPactado: precio,
      );

  /// Puede lanzar «Stock insuficiente»: anotar el repuesto lo saca del
  /// estante, así que si no hay, la línea no llega a existir.
  Future<void> agregarRepuesto({
    required int ordenId,
    required int productoId,
    required double cantidad,
    required int precioUnitario,
  }) =>
      _repo.agregarRepuesto(
        ordenId: ordenId,
        productoId: productoId,
        cantidad: cantidad,
        precioUnitario: precioUnitario,
      );

  Future<void> agregarCargo({
    required int ordenId,
    required String descripcion,
    required int precio,
  }) =>
      _repo.agregarCargo(
        ordenId: ordenId,
        descripcion: descripcion,
        precio: precio,
      );

  // Edición y baja de una línea ya escrita

  Future<void> eliminarLinea(LineaOrdenEditor linea) => switch (linea.tipo) {
        TipoLineaOrden.servicio => _repo.eliminarTarea(linea.id),
        TipoLineaOrden.repuesto => _repo.eliminarRepuesto(linea.id),
        TipoLineaOrden.cargo => _repo.eliminarCargo(linea.id),
      };

  /// Solo los repuestos tienen cantidad; en los otros dos tipos no hay columna
  /// que actualizar.
  Future<void> cambiarCantidad(LineaOrdenEditor linea, double cantidad) =>
      _repo.actualizarRepuesto(linea.id, cantidad: cantidad);

  Future<void> cambiarPrecio(LineaOrdenEditor linea, int precio) =>
      switch (linea.tipo) {
        TipoLineaOrden.servicio =>
          _repo.actualizarTarea(linea.id, precioPactado: precio),
        TipoLineaOrden.repuesto =>
          _repo.actualizarRepuesto(linea.id, precioUnitario: precio),
        TipoLineaOrden.cargo => _repo.actualizarCargo(linea.id, precio: precio),
      };

  Future<void> marcarCompletada(LineaOrdenEditor linea, {required bool hecha}) =>
      _repo.marcarTareaCompletada(linea.id, completado: hecha);

  // Cabecera y descuento

  Future<void> guardarCabecera({
    required int ordenId,
    required EstadoOrden estado,
    required int kilometrajeEntrada,
    required int motoId,
    required int clienteId,
    required String diagnostico,
    required String observaciones,
  }) =>
      _repo.actualizar(
        id: ordenId,
        estado: estado,
        kilometrajeEntrada: kilometrajeEntrada,
        motoId: motoId,
        clienteId: clienteId,
        diagnostico: diagnostico.trim().isEmpty ? null : diagnostico.trim(),
        observaciones:
            observaciones.trim().isEmpty ? null : observaciones.trim(),
      );

  /// El recorte al subtotal lo hace el repositorio: aquí no se puede saber, y
  /// además es **la única garantía** —no hay `CHECK` que lo cubra porque el
  /// subtotal de una orden es la suma de tres tablas.
  Future<void> fijarDescuento({required int ordenId, required int valor}) =>
      _repo.fijarDescuento(id: ordenId, valor: valor);
}
