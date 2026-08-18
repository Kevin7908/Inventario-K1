import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/ventas/ordenes/repositorio/repositrio_ordenes.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../../../inventario/modelo/movimiento_inventario.dart';
import '../../../inventario/repositorio/repositorio_inventario.dart';
import '../../../inventario/repositorio/repositorio_inventario_impl.dart';
import '../enum/enum_ordenes.dart';
import '../mapper/ordenes_mapper.dart';
import '../modelo/orden_detalle.dart';
import '../modelo/orden_resumen.dart';

class RepositorioOrdenesImpl implements RepositorioOrdenes {
  RepositorioOrdenesImpl(this._db);

  final AppDb _db;

  /// Agregar o quitar un repuesto mueve stock, y eso solo se hace por aquí.
  late final RepositorioInventario _inventario = RepositorioInventarioImpl(_db);

  // Getters para acceso rápido a tablas
  $TablaOrdenesServicioTable get _tablaOrdenes => _db.tablaOrdenesServicio;
  $TablaOrdenesTareaTable get _tablaTareas => _db.tablaOrdenesTarea;
  $TablaOrdenesRepuestoTable get _tablaRepuestos => _db.tablaOrdenesRepuesto;

  // SQL base para resúmenes. El nombre del cliente sale de `personas`: la
  // tabla `clientes` solo guarda lo propio del rol.
  static const _sqlSelectResumen = '''
    SELECT
      os.*,
      m.marca, m.modelo, m.anio, m.placa,
      (pe.nombres || ' ' || COALESCE(pe.apellidos, '')) AS cliente_nombre
    FROM ordenes_servicio os
    JOIN motos    m  ON m.id  = os.moto_id
    JOIN clientes c  ON c.id  = os.cliente_id
    JOIN personas pe ON pe.id = c.persona_id
  ''';

  @override
  Stream<List<OrdenResumen>> observarTodas() {
    return _db
        .customSelect(
          '$_sqlSelectResumen ORDER BY os.id DESC',
          readsFrom: {
            _tablaOrdenes,
            _db.tablaMoto,
            _db.tablaCliente,
            _db.tablaPersona,
          },
        )
        .watch()
        .map((rows) {
          return OrdenMapper.resumenesDesdeMapas(
            rows.map((r) => r.data).toList(growable: false),
          );
        });
  }

  @override
  Future<List<OrdenResumen>> obtenerTodas() async {
    final rows = await _db
        .customSelect('$_sqlSelectResumen ORDER BY os.id DESC')
        .get();
    return OrdenMapper.resumenesDesdeMapas(
      rows.map((r) => r.data).toList(growable: false),
    );
  }

  Future<OrdenResumen> _obtenerResumenPorId(int id) async {
    final row = await _db
        .customSelect(
          '$_sqlSelectResumen WHERE os.id = ?',
          variables: [Variable.withInt(id)],
        )
        .getSingleOrNull();

    if (row == null) throw Exception('Orden #$id no encontrada.');
    return OrdenMapper.resumenDesdeMap(row.data);
  }

  @override
  Future<OrdenDetalle> obtenerDetalle(int id) async {
    // Cabecera (Usamos customSelect para traer datos de moto/cliente)
    final cabeceraRow = await _db
        .customSelect(
          '$_sqlSelectResumen WHERE os.id = ?',
          variables: [Variable.withInt(id)],
        )
        .getSingleOrNull();

    if (cabeceraRow == null) throw Exception('Orden #$id no encontrada.');

    // Tareas (Con JOIN a Servicios y Técnicos)
    final tareasRows = await _db
        .customSelect(
          '''
      SELECT ot.*, s.nombre AS servicio_nombre,
             (pe.nombres || ' ' || COALESCE(pe.apellidos, '')) AS tecnico_nombre
      FROM ordenes_tareas ot
      JOIN servicios s  ON s.id  = ot.servicio_id
      JOIN tecnicos  t  ON t.id  = ot.tecnico_id
      JOIN personas  pe ON pe.id = t.persona_id
      WHERE ot.orden_id = ?
    ''',
          variables: [Variable.withInt(id)],
        )
        .get();

    // Repuestos (Con JOIN a Productos)
    final repuestosRows = await _db
        .customSelect(
          '''
      SELECT orp.*, p.nombre AS producto_nombre, p.precio_compra
      FROM ordenes_repuestos orp
      JOIN productos p ON p.id = orp.producto_id
      WHERE orp.orden_id = ?
    ''',
          variables: [Variable.withInt(id)],
        )
        .get();

    return OrdenMapper.detalleDesdeMapas(
      ordenRow: cabeceraRow.data,
      tareasRows: tareasRows.map((r) => r.data).toList(growable: false),
      repuestosRows: repuestosRows.map((r) => r.data).toList(growable: false),
    );
  }

  @override
  Future<OrdenResumen> agregar({
    required int motoId,
    required int clienteId,
    required int kilometrajeEntrada,
    String? diagnostico,
    String? observaciones,
  }) async {
    final id = await _db
        .into(_tablaOrdenes)
        .insert(
          OrdenMapper.aCompanionNuevo(
            motoId: motoId,
            clienteId: clienteId,
            kilometrajeEntrada: kilometrajeEntrada,
            diagnostico: diagnostico,
            observaciones: observaciones,
          ),
        );
    return _obtenerResumenPorId(id);
  }

  @override
  Future<OrdenResumen> actualizar({
    required int id,
    required EstadoOrden estado,
    required int kilometrajeEntrada,
    int? motoId,
    int? clienteId,
    String? diagnostico,
    String? observaciones,
  }) async {
    final fechaSalida = (estado == EstadoOrden.entregada)
        ? DateTime.now()
        : null;

    final companion = OrdenMapper.aCompanionActualizar(
      id: id,
      estado: estado,
      kilometrajeEntrada: kilometrajeEntrada,
      motoId: motoId,
      clienteId: clienteId,
      diagnostico: diagnostico,
      observaciones: observaciones,
      fechaSalida: fechaSalida,
    );

    final updatedCount = await (_db.update(
      _tablaOrdenes,
    )..where((t) => t.id.equals(id))).write(companion);

    if (updatedCount == 0) {
      throw Exception('No se pudo actualizar la orden #$id.');
    }

    // Propagar cambio de cliente a la factura vinculada (si existe)
    if (clienteId != null) {
      await _db.customUpdate(
        "UPDATE ventas SET cliente_id = ?, actualizado_en = datetime('now','localtime') WHERE orden_id = ?",
        variables: [Variable.withInt(clienteId), Variable.withInt(id)],
        updates: {_db.tablaVentas},
      );
    }

    return _obtenerResumenPorId(id);
  }

  @override
  Future<void> eliminar(int id) async {
    final deleted = await (_db.delete(
      _tablaOrdenes,
    )..where((t) => t.id.equals(id))).go();
    if (deleted == 0) throw Exception('Orden #$id no existe.');
  }

  @override
  Future<void> agregarTarea({
    required int ordenId,
    required int servicioId,
    required int tecnicoId,
    required int precioPactado,
    String? notas,
  }) async {
    await _db
        .into(_tablaTareas)
        .insert(
          OrdenMapper.tareaCompanionNuevo(
            ordenId: ordenId,
            servicioId: servicioId,
            tecnicoId: tecnicoId,
            precioPactado: precioPactado,
            notas: notas,
          ),
        );
  }

  @override
  Future<void> marcarTareaCompletada(
    int tareaId, {
    required bool completado,
  }) async {
    await (_db.update(_tablaTareas)..where((t) => t.id.equals(tareaId))).write(
      TablaOrdenesTareaCompanion(completado: Value(completado)),
    );
  }

  @override
  Future<void> actualizarTarea(
    int tareaId, {
    int? servicioId,
    int? tecnicoId,
    int? precioPactado,
    String? notas,
    bool? completado,
  }) async {
    await (_db.update(_tablaTareas)..where((t) => t.id.equals(tareaId))).write(
      TablaOrdenesTareaCompanion(
        servicioId:   servicioId   != null ? Value(servicioId)   : const Value.absent(),
        tecnicoId:    tecnicoId    != null ? Value(tecnicoId)    : const Value.absent(),
        precioPactado: precioPactado != null ? Value(precioPactado) : const Value.absent(),
        notas:        notas        != null ? Value(notas)        : const Value.absent(),
        completado:   completado   != null ? Value(completado)   : const Value.absent(),
      ),
    );
  }

  @override
  Future<void> eliminarTarea(int tareaId) async {
    await (_db.delete(_tablaTareas)..where((t) => t.id.equals(tareaId))).go();
  }

  @override
  Future<void> agregarRepuesto({
    required int ordenId,
    required int productoId,
    required double cantidad,
    required int precioUnitario,
  }) {
    // Línea y descuento van en la misma transacción: antes eran dos
    // escrituras sueltas y un fallo entre ellas dejaba el repuesto cobrado
    // sin descontar del inventario.
    return _db.transaction(() async {
      await _verificarStock(productoId, cantidad);

      await _db.into(_tablaRepuestos).insert(
        OrdenMapper.repuestoCompanionNuevo(
          ordenId: ordenId,
          productoId: productoId,
          cantidad: cantidad,
          precioUnitario: precioUnitario,
        ),
      );

      await _inventario.registrar(
        SolicitudMovimiento.salida(
          productoId: productoId,
          cantidad: cantidad,
          tipo: TipoMovimiento.salidaServicio,
          ordenId: ordenId,
        ),
      );
    });
  }

  /// Lanza si no alcanza el stock, con el mensaje que ve el usuario.
  ///
  /// La base también lo impediría —`productos.stock_actual` no puede quedar
  /// negativo—, pero el error de SQLite no se le puede enseñar a nadie.
  Future<void> _verificarStock(int productoId, double cantidad) async {
    final fila = await _db
        .customSelect(
          'SELECT stock_actual FROM productos WHERE id = ?',
          variables: [Variable.withInt(productoId)],
        )
        .getSingleOrNull();

    final disponible = (fila?.data['stock_actual'] as num?)?.toDouble() ?? 0;
    if (disponible >= cantidad) return;

    final texto = disponible % 1 == 0
        ? disponible.toInt().toString()
        : disponible.toStringAsFixed(2);
    throw Exception('Stock insuficiente. Disponible: $texto unidades.');
  }

  @override
  Future<void> actualizarRepuesto(
    int repuestoId, {
    double? cantidad,
    int? precioUnitario,
  }) {
    return _db.transaction(() async {
      final current = await (_db.select(_tablaRepuestos)
            ..where((t) => t.id.equals(repuestoId)))
          .getSingleOrNull();
      if (current == null) return;

      final cantidadNueva = cantidad ?? current.cantidad;
      final delta = cantidadNueva - current.cantidad;

      // Solo se mueve la diferencia: positivo = usó más y sale del inventario,
      // negativo = devolvió parte.
      if (delta != 0) {
        if (delta > 0) await _verificarStock(current.productoId, delta);
        await _inventario.registrar(
          SolicitudMovimiento(
            productoId: current.productoId,
            cantidad: -delta,
            tipo: delta > 0
                ? TipoMovimiento.salidaServicio
                : TipoMovimiento.devolucionServicio,
            ordenId: current.ordenId,
            notas: 'Cambio de cantidad en la orden',
          ),
        );
      }

      await (_db.update(_tablaRepuestos)..where((t) => t.id.equals(repuestoId)))
          .write(
        TablaOrdenesRepuestoCompanion(
          cantidad:       Value(cantidadNueva),
          precioUnitario: Value(precioUnitario ?? current.precioUnitario),
        ),
      );
    });
  }

  @override
  Future<void> eliminarRepuesto(int repuestoId) {
    return _db.transaction(() async {
      final current = await (_db.select(_tablaRepuestos)
            ..where((t) => t.id.equals(repuestoId)))
          .getSingleOrNull();
      if (current == null) return;

      await (_db.delete(_tablaRepuestos)
            ..where((t) => t.id.equals(repuestoId)))
          .go();

      await _inventario.registrar(
        SolicitudMovimiento.entrada(
          productoId: current.productoId,
          cantidad: current.cantidad,
          tipo: TipoMovimiento.devolucionServicio,
          ordenId: current.ordenId,
          notas: 'Repuesto retirado de la orden',
        ),
      );
    });
  }

  // Reportes

  @override
  Stream<Map<int, int>> observarConteoTareasPorTecnico() {
    final ordenesDistintas = _tablaTareas.ordenId.count(distinct: true);
    final consulta = _db.selectOnly(_tablaTareas)
      ..addColumns([_tablaTareas.tecnicoId, ordenesDistintas])
      ..groupBy([_tablaTareas.tecnicoId]);

    return consulta.watch().map((filas) {
      final conteo = <int, int>{};
      for (final fila in filas) {
        final id = fila.read(_tablaTareas.tecnicoId);
        if (id != null) conteo[id] = fila.read(ordenesDistintas) ?? 0;
      }
      return conteo;
    });
  }
}
