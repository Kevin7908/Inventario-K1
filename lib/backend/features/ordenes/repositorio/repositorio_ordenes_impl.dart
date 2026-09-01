import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/ordenes/repositorio/repositorio_ordenes.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../../inventario/modelo/movimiento_inventario.dart';
import '../../inventario/repositorio/repositorio_inventario.dart';
import '../../inventario/repositorio/repositorio_inventario_impl.dart';
import '../../../share/consecutivos/documento_consecutivo.dart';
import '../../../share/consecutivos/repositorio_consecutivos.dart';
import '../enum/enum_ordenes.dart';
import '../mapper/ordenes_mapper.dart';
import '../modelo/orden_detalle.dart';
import '../modelo/orden_resumen.dart';
import '../../../share/dominio/sesion_actual.dart';
import '../../bitacora/modelo/entrada_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora_impl.dart';
import '../../../share/dominio/permiso.dart';

class RepositorioOrdenesImpl with FirmaDeSesion implements RepositorioOrdenes {
  RepositorioOrdenesImpl(this._db, this.sesion);

  /// Quién firma lo que este repositorio escribe. La inyecta Riverpod
  /// desde `sesionActualProvider`: es una dependencia del constructor, no
  /// un registro global que se consulte por dentro.
  @override
  final SesionActual? sesion;

  late final RepositorioBitacora _bitacora = RepositorioBitacoraImpl(
    _db,
    sesion,
  );

  /// Deja el renglón de la bitácora, **dentro** de la transacción del cambio.
  Future<void> _anotar(
    AccionAuditada accion,
    int? id,
    String descripcion, {
    String? detalle,
  }) => _bitacora.anotar(
    Anotacion(
      entidad: EntidadAuditada.orden,
      accion: accion,
      entidadId: id,
      descripcion: descripcion,
      detalle: detalle,
    ),
  );

  final AppDb _db;

  /// Agregar o quitar un repuesto mueve stock, y eso solo se hace por aquí.
  late final RepositorioInventario _inventario = RepositorioInventarioImpl(
    _db,
    sesion,
  );

  // Getters para acceso rápido a tablas
  $TablaOrdenesServicioTable get _tablaOrdenes => _db.tablaOrdenesServicio;
  $TablaOrdenesTareaTable get _tablaTareas => _db.tablaOrdenesTarea;
  $TablaOrdenesRepuestoTable get _tablaRepuestos => _db.tablaOrdenesRepuesto;
  $TablaOrdenesCargoTable get _tablaCargos => _db.tablaOrdenesCargo;

  /// El número de orden sale de la tabla `consecutivos`, dentro de la misma
  /// transacción que la crea (§7.1).
  late final RepositorioConsecutivos _consecutivos = RepositorioConsecutivos(
    _db,
  );

  // El `FROM` y sus tres JOIN, aparte para que la consulta de la página y la
  // del `COUNT` filtren sobre exactamente las mismas filas. Si se separaran,
  // el total podría contar órdenes que la página no muestra.
  //
  // El nombre del cliente sale de `personas`: la tabla `clientes` solo guarda
  // lo propio del rol.
  //
  // La marca y el modelo son catálogo desde que dejaron de ser texto en
  // `motos`: `marcas_moto` entra con `JOIN` porque la FK es `NOT NULL`, y
  // `modelos_moto` con `LEFT JOIN` porque puede faltar.
  static const _sqlFromResumen = '''
    FROM ordenes_servicio os
    JOIN motos       m  ON m.id  = os.moto_id
    JOIN marcas_moto ma ON ma.id = m.marca_id
    LEFT JOIN modelos_moto md ON md.id = m.modelo_id
    JOIN clientes c  ON c.id  = os.cliente_id
    JOIN personas pe ON pe.id = c.persona_id
  ''';

  // Los tres subtotales y el técnico van en subconsultas correlacionadas y no
  // en un JOIN + GROUP BY: con tres tablas hijas a la vez, el JOIN multiplica
  // filas y las sumas salen infladas (dos tareas x tres repuestos = cada
  // importe contado seis veces). Traerlos abriendo cada orden sería el N+1
  // que prohíbe §5.
  static const _sqlSelectResumen =
      '''
    SELECT
      os.*,
      ma.nombre AS marca, md.nombre AS modelo, m.anio, m.placa,
      m.marca_id, m.modelo_id,
      (pe.nombres || ' ' || COALESCE(pe.apellidos, '')) AS cliente_nombre,
      (SELECT COALESCE(SUM(ot.precio_pactado), 0)
         FROM ordenes_tareas ot WHERE ot.orden_id = os.id) AS sub_mano_obra,
      (SELECT COALESCE(SUM(CAST(ROUND(orp.cantidad * orp.precio_unitario) AS INTEGER)), 0)
         FROM ordenes_repuestos orp WHERE orp.orden_id = os.id) AS sub_repuestos,
      (SELECT COALESCE(SUM(oc.precio), 0)
         FROM ordenes_cargos oc WHERE oc.orden_id = os.id) AS sub_cargos,
      (SELECT COUNT(DISTINCT ot.tecnico_id)
         FROM ordenes_tareas ot WHERE ot.orden_id = os.id) AS tecnicos_distintos,
      (SELECT tpe.nombres || ' ' || COALESCE(tpe.apellidos, '')
         FROM ordenes_tareas ot
         JOIN tecnicos tec ON tec.id = ot.tecnico_id
         JOIN personas tpe ON tpe.id = tec.persona_id
        WHERE ot.orden_id = os.id
        ORDER BY ot.id LIMIT 1) AS tecnico_nombre
  '''
      '$_sqlFromResumen';

  /// Las tablas que hay que vigilar para que el stream del listado se entere
  /// de un cambio. Si falta una, la lista se queda desactualizada en silencio
  /// (§5): las tres hijas están porque los subtotales salen de ellas.
  Set<ResultSetImplementation<dynamic, dynamic>> get _fuentesResumen => {
    _tablaOrdenes,
    _tablaTareas,
    _tablaRepuestos,
    _tablaCargos,
    _db.tablaMoto,
    // Si faltaran, renombrar una marca no volvería a emitir y el listado se
    // quedaría con el nombre viejo hasta reabrir la pantalla.
    _db.tablaMarcaMoto,
    _db.tablaModeloMoto,
    _db.tablaCliente,
    _db.tablaPersona,
    _db.tablaTecnico,
  };

  @override
  Stream<List<OrdenResumen>> observarTodas() {
    exigir(Permiso.ordenesVer);
    return _db
        .customSelect(
          '$_sqlSelectResumen ORDER BY os.id DESC',
          readsFrom: _fuentesResumen,
        )
        .watch()
        .map((rows) {
          return OrdenMapper.resumenesDesdeMapas(
            rows.map((r) => r.data).toList(growable: false),
          );
        });
  }

  /// Traduce [FiltroOrdenes] al `WHERE` que comparten la consulta de la página
  /// y la del total, junto a sus variables **en el mismo orden**.
  ///
  /// Va con parámetros y no interpolando el texto del buscador: una placa con
  /// comilla simple rompería la consulta, y §5 avisa de que a este SQL no lo
  /// revisa el analizador.
  ({String sql, List<Variable<Object>> variables}) _whereListado(
    FiltroOrdenes filtro,
  ) {
    final condiciones = <String>[];
    final variables = <Variable<Object>>[];

    final estado = filtro.estado;
    if (estado != null) {
      condiciones.add('os.estado = ?');
      variables.add(Variable.withString(estado.aTexto));
    }

    final texto = filtro.busqueda.trim();
    if (texto.isNotEmpty) {
      // `LIKE '%x%'` no usa índice, y está bien: son las órdenes de un taller,
      // no millones de filas (§5). Si dejara de estarlo, la respuesta es FTS5.
      condiciones.add('''(
        LOWER(os.numero) LIKE ?
        OR LOWER(pe.nombres || ' ' || COALESCE(pe.apellidos, '')) LIKE ?
        OR LOWER(ma.nombre || ' ' || COALESCE(md.nombre, '') || ' ' ||
                 COALESCE(CAST(m.anio AS TEXT), '')) LIKE ?
        OR LOWER(COALESCE(m.placa, '')) LIKE ?
      )''');
      final patron = '%${texto.toLowerCase()}%';
      for (var i = 0; i < 4; i++) {
        variables.add(Variable.withString(patron));
      }
    }

    return (
      sql: condiciones.isEmpty ? '' : 'WHERE ${condiciones.join(' AND ')}',
      variables: variables,
    );
  }

  @override
  Stream<PaginaOrdenes> observarPagina({
    required FiltroOrdenes filtro,
    required int pagina,
    required int tamano,
  }) {
    exigir(Permiso.ordenesVer);
    final donde = _whereListado(filtro);

    final consultaPagina = _db.customSelect(
      '$_sqlSelectResumen ${donde.sql} ORDER BY os.id DESC LIMIT ? OFFSET ?',
      variables: [
        ...donde.variables,
        Variable.withInt(tamano),
        Variable.withInt(pagina * tamano),
      ],
      readsFrom: _fuentesResumen,
    );

    // El total va en su propia consulta: el `LIMIT` no debe afectarlo. Repite
    // los JOIN porque la búsqueda mira el cliente y la moto.
    final consultaTotal = _db.customSelect(
      'SELECT COUNT(*) AS total $_sqlFromResumen ${donde.sql}',
      variables: donde.variables,
    );

    return consultaPagina.watch().asyncMap((filas) async {
      final fila = await consultaTotal.getSingleOrNull();
      return PaginaOrdenes(
        items: OrdenMapper.resumenesDesdeMapas(
          filas.map((f) => f.data).toList(growable: false),
        ),
        total: fila?.read<int>('total') ?? 0,
      );
    });
  }

  @override
  Future<List<OrdenResumen>> obtenerTodas() async {
    exigir(Permiso.ordenesVer);
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
    exigir(Permiso.ordenesVer);
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

    final cargosRows = await _db
        .customSelect(
          'SELECT * FROM ordenes_cargos WHERE orden_id = ? ORDER BY id',
          variables: [Variable.withInt(id)],
        )
        .get();

    return OrdenMapper.detalleDesdeMapas(
      ordenRow: cabeceraRow.data,
      tareasRows: tareasRows.map((r) => r.data).toList(growable: false),
      repuestosRows: repuestosRows.map((r) => r.data).toList(growable: false),
      cargosRows: cargosRows.map((r) => r.data).toList(growable: false),
    );
  }

  @override
  Future<OrdenResumen> agregar({
    required int motoId,
    required int clienteId,
    required int kilometrajeEntrada,
    String? diagnostico,
    String? observaciones,
  }) {
    exigir(Permiso.ordenesCrear);

    // El número se pide dentro de la transacción que inserta la orden: si el
    // `INSERT` falla, el consecutivo se devuelve y la serie sigue sin huecos.
    return _db.transaction(() async {
      final id = await _db
          .into(_tablaOrdenes)
          .insert(
            OrdenMapper.aCompanionNuevo(
              usuarioId: autorId,
              numero: await _consecutivos.siguiente(DocumentoConsecutivo.orden),
              motoId: motoId,
              clienteId: clienteId,
              kilometrajeEntrada: kilometrajeEntrada,
              diagnostico: diagnostico,
              observaciones: observaciones,
            ),
          );
      return _obtenerResumenPorId(id);
    });
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

    // Cerrar la orden ya no mueve inventario: los repuestos salieron del
    // estante cuando se anotaron. Lo único que queda es **anular**, que los
    // devuelve, y va en la misma transacción que el cambio de estado: si la
    // devolución falla, la orden no se queda anulada con el stock sin volver.
    await _db.transaction(() async {
      final antes = await (_db.select(
        _tablaOrdenes,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (antes == null) {
        throw Exception('No se pudo actualizar la orden #$id.');
      }

      // Solo la **transición** a anulada devuelve. Reanular una orden ya
      // anulada devolvería el stock por segunda vez e inflaría el inventario.
      final yaAnulada = antes.estado == EstadoOrden.anulada.name.toUpperCase();
      if (estado == EstadoOrden.anulada && !yaAnulada) {
        await _devolverInventario(id);
      }

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
    });

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
    exigir(Permiso.ordenesEliminar);
    await _db.transaction(() async {
      // El número se lee antes: después la orden ya no está para decirlo.
      final antes = await (_db.select(
        _tablaOrdenes,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      // Una orden que se fió no se borra: la `restrict` de `deudores.orden_id`
      // lo impediría igual, pero con un error de SQLite que no se le puede
      // enseñar a nadie. Y borrarla dejaría la deuda cobrando líneas que ya no
      // se pueden mirar en ninguna parte.
      final deuda = await (_db.select(_db.tablaDeudor)
            ..where((t) => t.ordenId.equals(id))
            ..limit(1))
          .getSingleOrNull();
      if (deuda != null) {
        throw Exception(
          'La orden ${antes?.numero ?? '#$id'} se fió en la deuda '
          '${deuda.numero}: elimina primero la deuda si de verdad hay que '
          'borrarla.',
        );
      }

      final deleted = await (_db.delete(
        _tablaOrdenes,
      )..where((t) => t.id.equals(id))).go();
      if (deleted == 0) throw Exception('Orden #$id no existe.');

      await _anotar(
        AccionAuditada.elimino,
        id,
        antes == null ? 'Orden #$id' : 'Orden ${antes.numero}',
      );
    });
  }

  @override
  Future<void> agregarTarea({
    required int ordenId,
    required int servicioId,
    required int tecnicoId,
    required int precioPactado,
    String? notas,
  }) async {
    exigir(Permiso.ordenesEditar);

    await _db
        .into(_tablaTareas)
        .insert(
          OrdenMapper.tareaCompanionNuevo(
            usuarioId: autorId,
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
        servicioId: servicioId != null
            ? Value(servicioId)
            : const Value.absent(),
        tecnicoId: tecnicoId != null ? Value(tecnicoId) : const Value.absent(),
        precioPactado: precioPactado != null
            ? Value(precioPactado)
            : const Value.absent(),
        notas: notas != null ? Value(notas) : const Value.absent(),
        completado: completado != null
            ? Value(completado)
            : const Value.absent(),
      ),
    );
    // Bajar el precio pactado baja el subtotal, y la rebaja que antes cabía
    // puede dejar de caber.
    if (precioPactado != null) await _reajustarDescuentoDeTarea(tareaId);
  }

  @override
  Future<void> eliminarTarea(int tareaId) async {
    await _db.transaction(() async {
      final actual = await (_db.select(
        _tablaTareas,
      )..where((t) => t.id.equals(tareaId))).getSingleOrNull();
      if (actual == null) return;

      await (_db.delete(_tablaTareas)..where((t) => t.id.equals(tareaId))).go();
      await _reajustarDescuento(actual.ordenId);
    });
  }

  @override
  Future<void> agregarRepuesto({
    required int ordenId,
    required int productoId,
    required double cantidad,
    required int precioUnitario,
  }) {
    exigir(Permiso.ordenesEditar);

    // Anotar el repuesto **es** sacarlo del estante: la pieza queda apartada
    // para esta moto aunque el mecánico todavía no la haya montado. Por eso
    // se verifica y se descuenta aquí, y no al cerrar la orden: así el error
    // llega pegado al gesto que lo causa y no media hora después.
    return _db.transaction(() async {
      await _verificarStock(productoId, cantidad);

      await _db
          .into(_tablaRepuestos)
          .insert(
            OrdenMapper.repuestoCompanionNuevo(
              usuarioId: autorId,
              ordenId: ordenId,
              productoId: productoId,
              cantidad: cantidad,
              precioUnitario: precioUnitario,
            ),
          );

      // Agregar sube el subtotal, así que la rebaja no puede dejar de caber:
      // no hace falta reajustarla.
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
  ///
  /// **Nombra el producto** porque el mismo mensaje sale en dos sitios: al
  /// agregar la línea, donde el usuario sabe cuál es, y al anular, donde no.
  Future<void> _verificarStock(int productoId, double cantidad) async {
    final fila = await _db
        .customSelect(
          'SELECT stock_actual, nombre FROM productos WHERE id = ?',
          variables: [Variable.withInt(productoId)],
        )
        .getSingleOrNull();

    final disponible = (fila?.data['stock_actual'] as num?)?.toDouble() ?? 0;
    if (disponible >= cantidad) return;

    final nombre = fila?.data['nombre'] as String? ?? 'el repuesto';
    throw Exception(
      'No hay stock de "$nombre": se necesitan ${_cantidad(cantidad)} y '
      'quedan ${_cantidad(disponible)}.',
    );
  }

  /// Una cantidad sin `.0` de más: los repuestos se cuentan por unidades, pero
  /// el aceite va por litros.
  static String _cantidad(double valor) =>
      valor % 1 == 0 ? valor.toInt().toString() : valor.toStringAsFixed(2);

  @override
  Future<void> actualizarRepuesto(
    int repuestoId, {
    double? cantidad,
    int? precioUnitario,
  }) {
    return _db.transaction(() async {
      final current = await (_db.select(
        _tablaRepuestos,
      )..where((t) => t.id.equals(repuestoId))).getSingleOrNull();
      if (current == null) return;

      final cantidadNueva = cantidad ?? current.cantidad;
      final delta = cantidadNueva - current.cantidad;

      // Se mueve solo la diferencia. Subir de 2 a 5 saca tres piezas más;
      // bajar de 5 a 2 devuelve tres. Registrar la cantidad entera de nuevo
      // duplicaría la salida.
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

      await (_db.update(
        _tablaRepuestos,
      )..where((t) => t.id.equals(repuestoId))).write(
        TablaOrdenesRepuestoCompanion(
          cantidad: Value(cantidadNueva),
          precioUnitario: Value(precioUnitario ?? current.precioUnitario),
        ),
      );
    });
  }

  @override
  Future<void> eliminarRepuesto(int repuestoId) {
    return _db.transaction(() async {
      final current = await (_db.select(
        _tablaRepuestos,
      )..where((t) => t.id.equals(repuestoId))).getSingleOrNull();
      if (current == null) return;

      await (_db.delete(
        _tablaRepuestos,
      )..where((t) => t.id.equals(repuestoId))).go();

      // La línea existía, así que su pieza había salido: quitarla la devuelve.
      await _inventario.registrar(
        SolicitudMovimiento.entrada(
          productoId: current.productoId,
          cantidad: current.cantidad,
          tipo: TipoMovimiento.devolucionServicio,
          ordenId: current.ordenId,
          notas: 'Repuesto retirado de la orden',
        ),
      );

      await _reajustarDescuento(current.ordenId);
    });
  }

  // Reportes

  @override
  Stream<Map<int, int>> observarConteoTareasPorTecnico() {
    exigir(Permiso.ordenesVer);
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

  @override
  Future<OrdenResumen> fijarDescuento({
    required int id,
    required int valor,
  }) async {
    // El recorte va contra el subtotal real de las tres tablas hijas. Sin
    // esto el total quedaría en negativo y ningún `CHECK` lo atajaría: el
    // subtotal de una orden no es una columna.
    final fila = await _db
        .customSelect(
          '''
      SELECT
        (SELECT COALESCE(SUM(precio_pactado), 0)
           FROM ordenes_tareas WHERE orden_id = ?) +
        (SELECT COALESCE(SUM(CAST(ROUND(cantidad * precio_unitario) AS INTEGER)), 0)
           FROM ordenes_repuestos WHERE orden_id = ?) +
        (SELECT COALESCE(SUM(precio), 0)
           FROM ordenes_cargos WHERE orden_id = ?) AS sub
      ''',
          variables: [
            Variable.withInt(id),
            Variable.withInt(id),
            Variable.withInt(id),
          ],
        )
        .getSingle();

    final subtotal = (fila.data['sub'] as num? ?? 0).round();
    final recortado = valor < 0 ? 0 : (valor > subtotal ? subtotal : valor);

    await (_db.update(_tablaOrdenes)..where((t) => t.id.equals(id))).write(
      TablaOrdenesServicioCompanion(
        descuento: Value(recortado),
        actualizadoEn: Value(DateTime.now()),
      ),
    );
    return _obtenerResumenPorId(id);
  }

  @override
  Stream<ResumenOrdenes> observarResumen() {
    exigir(Permiso.ordenesVer);
    // Un `COUNT` con `filter` por estado, todo en una pasada. "En proceso" es
    // ABIERTA y "pendientes" LISTA —la moto ya está lista pero no se ha
    // entregado—, que es lo que separan las tarjetas del diseño.
    final t = _tablaOrdenes;
    final total = t.id.count();
    final enProceso = t.id.count(
      filter: t.estado.equals(EstadoOrden.abierta.aTexto),
    );
    final pendientes = t.id.count(
      filter: t.estado.equals(EstadoOrden.lista.aTexto),
    );
    final completadas = t.id.count(
      filter: t.estado.equals(EstadoOrden.entregada.aTexto),
    );

    final consulta = _db.selectOnly(t)
      ..addColumns([total, enProceso, pendientes, completadas]);

    return consulta.watchSingleOrNull().map(
      (fila) => (
        total: fila?.read(total) ?? 0,
        enProceso: fila?.read(enProceso) ?? 0,
        pendientes: fila?.read(pendientes) ?? 0,
        completadas: fila?.read(completadas) ?? 0,
      ),
    );
  }

  // Cargos

  @override
  Future<void> agregarCargo({
    required int ordenId,
    required String descripcion,
    required int precio,
  }) async {
    exigir(Permiso.ordenesEditar);

    final limpia = descripcion.trim();
    if (limpia.isEmpty) {
      throw Exception('El cargo necesita una descripción.');
    }
    await _db
        .into(_tablaCargos)
        .insert(
          OrdenMapper.cargoCompanionNuevo(
            usuarioId: autorId,
            ordenId: ordenId,
            descripcion: limpia,
            precio: precio,
          ),
        );
  }

  @override
  Future<void> actualizarCargo(
    int cargoId, {
    String? descripcion,
    int? precio,
  }) async {
    // Cambiar el precio de un cargo puede dejar el descuento por encima del
    // nuevo subtotal, así que las dos escrituras van juntas.
    await _db.transaction(() async {
      final actual = await (_db.select(
        _tablaCargos,
      )..where((t) => t.id.equals(cargoId))).getSingleOrNull();
      if (actual == null) return;

      await (_db.update(
        _tablaCargos,
      )..where((t) => t.id.equals(cargoId))).write(
        TablaOrdenesCargoCompanion(
          descripcion: descripcion != null
              ? Value(descripcion.trim())
              : const Value.absent(),
          precio: precio != null ? Value(precio) : const Value.absent(),
        ),
      );

      await _reajustarDescuento(actual.ordenId);
    });
  }

  @override
  Future<void> eliminarCargo(int cargoId) async {
    await _db.transaction(() async {
      final actual = await (_db.select(
        _tablaCargos,
      )..where((t) => t.id.equals(cargoId))).getSingleOrNull();
      if (actual == null) return;

      await (_db.delete(_tablaCargos)..where((t) => t.id.equals(cargoId))).go();
      await _reajustarDescuento(actual.ordenId);
    });
  }

  /// Vuelve a recortar el descuento contra el subtotal actual.
  ///
  /// Hace falta cada vez que una línea desaparece o baja de precio: la rebaja
  /// que antes cabía puede dejar de caber, y aquí no hay `CHECK` que lo avise.
  Future<void> _reajustarDescuentoDeTarea(int tareaId) async {
    final tarea = await (_db.select(
      _tablaTareas,
    )..where((t) => t.id.equals(tareaId))).getSingleOrNull();
    if (tarea != null) await _reajustarDescuento(tarea.ordenId);
  }

  /// Devuelve al inventario todo lo que había salido por esta orden.
  ///
  /// Lo llama solo el paso a `ANULADA`. Va agrupado por producto y no línea a
  /// línea: dos líneas del mismo repuesto son dos salidas pero una sola
  /// devolución, y así el movimiento de vuelta se lee igual que la orden.
  Future<void> _devolverInventario(int ordenId) async {
    final lineas = await (_db.select(
      _tablaRepuestos,
    )..where((t) => t.ordenId.equals(ordenId))).get();
    if (lineas.isEmpty) return;

    final porProducto = <int, double>{};
    for (final linea in lineas) {
      porProducto[linea.productoId] =
          (porProducto[linea.productoId] ?? 0) + linea.cantidad;
    }

    await _inventario.registrarVarios([
      for (final entrada in porProducto.entries)
        SolicitudMovimiento.entrada(
          productoId: entrada.key,
          cantidad: entrada.value,
          tipo: TipoMovimiento.devolucionServicio,
          ordenId: ordenId,
          notas: 'Orden anulada',
        ),
    ]);
  }

  Future<void> _reajustarDescuento(int ordenId) async {
    final orden = await (_db.select(
      _tablaOrdenes,
    )..where((t) => t.id.equals(ordenId))).getSingleOrNull();
    if (orden == null || orden.descuento == 0) return;
    await fijarDescuento(id: ordenId, valor: orden.descuento);
  }
}
