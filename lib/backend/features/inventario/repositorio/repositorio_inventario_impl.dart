import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../mapper/movimiento_mapper.dart';
import '../modelo/movimiento_inventario.dart';
import 'repositorio_inventario.dart';
import '../../../share/dominio/permiso.dart';
import '../../../share/dominio/sesion_actual.dart';

class RepositorioInventarioImpl with FirmaDeSesion implements RepositorioInventario {
  RepositorioInventarioImpl(this._db, this.sesion);

  /// Quién firma lo que este repositorio escribe. La inyecta Riverpod
  /// desde `sesionActualProvider`: es una dependencia del constructor, no
  /// un registro global que se consulte por dentro.
  @override
  final SesionActual? sesion;

  final AppDb _db;

  $TablaMovimientoInventarioTable get _tabla => _db.tablaMovimientoInventario;

  @override
  Future<void> registrar(SolicitudMovimiento solicitud) =>
      registrarVarios([solicitud]);

  @override
  Future<void> registrarVarios(List<SolicitudMovimiento> solicitudes) {
    if (solicitudes.isEmpty) return Future.value();

    return _db.transaction(() async {
      for (final solicitud in solicitudes) {
        await _db
            .into(_tabla)
            .insert(MovimientoMapper.solicitudACompanion(solicitud, autorId));

        // El caché se ajusta con un `UPDATE` relativo y no leyendo-sumando-
        // escribiendo: así es atómico y no hay ciclo que se pueda entrelazar.
        await _db.customUpdate(
          'UPDATE productos SET stock_actual = stock_actual + ?, '
          'actualizado_en = ? WHERE id = ?',
          variables: [
            Variable.withReal(solicitud.cantidad),
            Variable.withDateTime(DateTime.now()),
            Variable.withInt(solicitud.productoId),
          ],
          updates: {_db.tablaProducto},
        );
      }
    });
  }

  @override
  Future<void> registrarEntradaCompra({
    required int productoId,
    required double cantidad,
    String? notas,
  }) {
    exigir(Permiso.inventarioEntrada);
    final limpio = notas?.trim();

    return registrar(
      SolicitudMovimiento.entrada(
        productoId: productoId,
        cantidad: cantidad,
        tipo: TipoMovimiento.entradaCompra,
        notas: limpio == null || limpio.isEmpty ? null : limpio,
      ),
    );
  }

  @override
  Stream<List<MovimientoInventario>> observarPorProducto(
    int productoId, {
    int? limite,
  }) {
    final consulta = _db.select(_tabla)
      ..where((m) => m.productoId.equals(productoId))
      // El `id` desempata: dos movimientos de la misma venta caen en el mismo
      // segundo y sin esto quedarían en un orden arbitrario.
      ..orderBy([
        (m) => OrderingTerm.desc(m.creadoEn),
        (m) => OrderingTerm.desc(m.id),
      ]);

    if (limite != null) consulta.limit(limite);

    return consulta
        .watch()
        .map((filas) => filas.map(MovimientoMapper.filaAModelo).toList());
  }

  @override
  Stream<PaginaMovimientos> observarPagina({
    required FiltroMovimientos filtro,
    required int pagina,
    required int tamano,
  }) {
    // El kardex dice quién sacó qué del taller. Esconder el ítem del sidebar
    // es orden; esta línea es el control (`CLAUDE.md` §7 bis).
    exigir(Permiso.inventarioMovimientosVer);

    final (where, variables) = _condicion(filtro);

    // Dos consultas: el total no lo puede recortar el `LIMIT`, o el paginador
    // diría que hay una página cuando hay veinte.
    final consultaTotal = _db.customSelect(
      'SELECT COUNT(*) AS total FROM movimientos_inventario m '
      'INNER JOIN productos p ON p.id = m.producto_id $where',
      variables: variables,
      readsFrom: _tablasDelKardex,
    );

    return _db
        .customSelect(
          '$_sqlSelectDetalle $where '
          'ORDER BY m.creado_en DESC, m.id DESC LIMIT ? OFFSET ?',
          variables: [
            ...variables,
            Variable.withInt(tamano),
            Variable.withInt(pagina * tamano),
          ],
          readsFrom: _tablasDelKardex,
        )
        .watch()
        .asyncMap((filas) async {
      final fila = await consultaTotal.getSingleOrNull();
      return PaginaMovimientos(
        items: filas
            .map((f) => MovimientoMapper.detalleDesdeMapa(f.data))
            .toList(),
        total: fila?.read<int>('total') ?? 0,
      );
    });
  }

  /// El `SELECT` del kardex. El documento de origen se resuelve con cuatro
  /// `LEFT JOIN` y un `COALESCE` y no con cuatro consultas: el `CHECK` de la
  /// tabla garantiza que como mucho una referencia está puesta, así que el
  /// `COALESCE` no puede tapar un segundo número.
  static const _sqlSelectDetalle = '''
    SELECT m.*,
           p.nombre AS producto_nombre,
           p.sku    AS producto_sku,
           TRIM(pe.nombres || ' ' || COALESCE(pe.apellidos, '')) AS usuario,
           COALESCE(v.numero_factura, o.numero, r.numero, du.numero, co.numero)
             AS numero_documento
    FROM movimientos_inventario m
    INNER JOIN productos p  ON p.id  = m.producto_id
    INNER JOIN usuarios  u  ON u.id  = m.usuario_id
    INNER JOIN personas  pe ON pe.id = u.persona_id
    LEFT  JOIN ventas    v  ON v.id  = m.venta_id
    LEFT  JOIN ordenes_servicio o ON o.id = m.orden_id
    LEFT  JOIN reservas  r  ON r.id  = m.reserva_id
    LEFT  JOIN deudores  du ON du.id = m.deudor_id
    LEFT  JOIN compras   co ON co.id = m.compra_id
  ''';

  /// Las tablas que hacen re-emitir el stream. Si falta una, el kardex no se
  /// entera de que cambió (`REGLAS_BD.md` §5).
  Set<TableInfo<Table, dynamic>> get _tablasDelKardex => {
        _tabla,
        _db.tablaProducto,
        _db.tablaUsuario,
        _db.tablaPersona,
        _db.tablaVentas,
        _db.tablaOrdenesServicio,
        _db.tablaReserva,
        _db.tablaDeudor,
        _db.tablaCompra,
      };

  /// El `WHERE` y sus variables, en el mismo orden. Se arma una sola vez y lo
  /// comparten la consulta de la página y la del total: si divergieran, el
  /// paginador contaría filas que no muestra.
  (String, List<Variable>) _condicion(FiltroMovimientos filtro) {
    final condiciones = <String>[];
    final variables = <Variable>[];

    if (filtro.productoId != null) {
      condiciones.add('m.producto_id = ?');
      variables.add(Variable.withInt(filtro.productoId!));
    }
    if (filtro.tipo != null) {
      condiciones.add('m.tipo = ?');
      variables.add(Variable.withString(filtro.tipo!.codigo));
    }
    if (filtro.usuarioId != null) {
      condiciones.add('m.usuario_id = ?');
      variables.add(Variable.withInt(filtro.usuarioId!));
    }
    if (filtro.soloEntradas != null) {
      // Con el signo dentro de la cantidad, entra o sale es una comparación y
      // no una lista de diez tipos que habría que ampliar con cada uno nuevo.
      condiciones.add(filtro.soloEntradas! ? 'm.cantidad > 0' : 'm.cantidad < 0');
    }
    if (filtro.desde != null) {
      condiciones.add('m.creado_en >= ?');
      variables.add(Variable.withDateTime(filtro.desde!));
    }
    if (filtro.hasta != null) {
      condiciones.add('m.creado_en <= ?');
      variables.add(Variable.withDateTime(filtro.hasta!));
    }

    final busqueda = filtro.busqueda.trim();
    if (busqueda.isNotEmpty) {
      condiciones.add(
        '(p.nombre LIKE ?1 OR p.sku LIKE ?1 OR m.notas LIKE ?1)'
            .replaceAll('?1', '?'),
      );
      final patron = Variable.withString('%$busqueda%');
      variables.addAll([patron, patron, patron]);
    }

    if (condiciones.isEmpty) return ('', variables);
    return ('WHERE ${condiciones.join(' AND ')}', variables);
  }

  @override
  Future<double> stockReconstruido(int productoId) async {
    final suma = _tabla.cantidad.sum();
    final fila = await (_db.selectOnly(_tabla)
          ..addColumns([suma])
          ..where(_tabla.productoId.equals(productoId)))
        .getSingleOrNull();
    return fila?.read(suma) ?? 0;
  }

  @override
  Future<Map<int, double>> descuadres() async {
    // Un solo `GROUP BY` contra el catálogo entero. El `LEFT JOIN` incluye a
    // los productos sin ningún movimiento: si uno de esos tiene stock, también
    // está descuadrado.
    final filas = await _db.customSelect(
      '''
      SELECT p.id AS id,
             p.stock_actual - COALESCE(SUM(m.cantidad), 0) AS diferencia
      FROM productos p
      LEFT JOIN movimientos_inventario m ON m.producto_id = p.id
      GROUP BY p.id
      HAVING ABS(diferencia) > 0.0001
      ''',
      readsFrom: {_db.tablaProducto, _tabla},
    ).get();

    return {
      for (final fila in filas)
        fila.read<int>('id'): fila.read<double>('diferencia'),
    };
  }
}
