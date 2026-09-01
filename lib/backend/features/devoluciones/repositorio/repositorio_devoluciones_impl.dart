import 'package:drift/drift.dart';

import '../../../../core/resultado.dart';
import '../../../share/consecutivos/documento_consecutivo.dart';
import '../../../share/consecutivos/repositorio_consecutivos.dart';
import '../../../share/database/app_db.dart';
import '../../../share/dominio/permiso.dart';
import '../../../share/dominio/sesion_actual.dart';
import '../../bitacora/modelo/entrada_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora_impl.dart';
import '../../inventario/modelo/movimiento_inventario.dart';
import '../../inventario/repositorio/repositorio_inventario.dart';
import '../../inventario/repositorio/repositorio_inventario_impl.dart';
import '../enum/enum_devoluciones.dart';
import '../mapper/devoluciones_mapper.dart';
import '../modelo/devolucion.dart';
import 'repositorio_devoluciones.dart';

class RepositorioDevolucionesImpl
    with FirmaDeSesion
    implements RepositorioDevoluciones {
  RepositorioDevolucionesImpl(this._db, this.sesion);

  /// Quién firma lo que este repositorio escribe. La inyecta Riverpod desde
  /// `sesionActualProvider`: es una dependencia del constructor, no un
  /// registro global que se consulte por dentro.
  @override
  final SesionActual? sesion;

  final AppDb _db;

  /// Devolver repone stock, y el stock solo se mueve por aquí.
  late final RepositorioInventario _inventario =
      RepositorioInventarioImpl(_db, sesion);

  late final RepositorioConsecutivos _consecutivos =
      RepositorioConsecutivos(_db);

  late final RepositorioBitacora _bitacora =
      RepositorioBitacoraImpl(_db, sesion);

  $TablaDevolucionTable get _tabla => _db.tablaDevolucion;
  $TablaDevolucionDetalleTable get _detalles => _db.tablaDevolucionDetalle;

  /// Margen para comparar cantidades: `cantidad` es `REAL` y devolver 0.3 y
  /// 0.7 de una línea de 1.0 no puede fallar por el último bit. Es el mismo
  /// que usa la guarda de la base.
  static const _epsilon = 0.0001;

  /// Las tablas que hacen re-emitir los streams de este módulo. Si falta una,
  /// la pantalla no se entera de que cambió (`REGLAS_BD.md` §5).
  Set<TableInfo<Table, dynamic>> get _tablasDelModulo => {
        _tabla,
        _detalles,
        _db.tablaVentaDetalles,
        _db.tablaVentas,
        _db.tablaUsuario,
        _db.tablaPersona,
      };

  // Lecturas

  @override
  Future<List<LineaDevolvible>> lineasDevolvibles(int ventaId) async {
    // Lo ya devuelto sale de un subselect agregado, no de traer las
    // devoluciones y restarlas en Dart.
    final filas = await _db.customSelect(
      '''
      SELECT vd.id            AS id,
             vd.producto_id   AS producto_id,
             vd.descripcion   AS descripcion,
             vd.cantidad      AS cantidad,
             vd.precio_unitario AS precio_unitario,
             COALESCE((SELECT SUM(dd.cantidad) FROM devolucion_detalles dd
                       WHERE dd.venta_detalle_id = vd.id), 0) AS devuelta
      FROM venta_detalles vd
      WHERE vd.venta_id = ?
      ORDER BY vd.id
      ''',
      variables: [Variable.withInt(ventaId)],
      readsFrom: _tablasDelModulo,
    ).get();

    return filas
        .map((f) => DevolucionesMapper.devolvibleDesdeMapa(f.data))
        .toList();
  }

  @override
  Future<Map<int, double>> devueltoPorLinea(int ventaId) async {
    final filas = await _db.customSelect(
      '''
      SELECT dd.venta_detalle_id AS linea, SUM(dd.cantidad) AS devuelta
      FROM devolucion_detalles dd
      INNER JOIN venta_detalles vd ON vd.id = dd.venta_detalle_id
      WHERE vd.venta_id = ?
      GROUP BY dd.venta_detalle_id
      ''',
      variables: [Variable.withInt(ventaId)],
      readsFrom: _tablasDelModulo,
    ).get();

    return {
      for (final f in filas)
        f.read<int>('linea'): f.read<double>('devuelta'),
    };
  }

  @override
  Stream<Map<int, int>> observarTotalDevueltoPorVenta() {
    return _db
        .customSelect(
          '''
          SELECT venta_id AS venta_id, SUM(total) AS devuelto
          FROM devoluciones
          GROUP BY venta_id
          ''',
          readsFrom: {_tabla},
        )
        .watch()
        .map((filas) => {
              for (final f in filas)
                f.read<int>('venta_id'): f.read<int>('devuelto'),
            });
  }

  @override
  Stream<List<Devolucion>> observarPorVenta(int ventaId) {
    return _db
        .customSelect(
          '''
          SELECT d.*,
                 v.numero_factura AS numero_factura,
                 TRIM(p.nombres || ' ' || COALESCE(p.apellidos, '')) AS recibido_por
          FROM devoluciones d
          INNER JOIN ventas v   ON v.id = d.venta_id
          INNER JOIN usuarios u ON u.id = d.usuario_id
          INNER JOIN personas p ON p.id = u.persona_id
          WHERE d.venta_id = ?
          ORDER BY d.id DESC
          ''',
          variables: [Variable.withInt(ventaId)],
          readsFrom: _tablasDelModulo,
        )
        .watch()
        .asyncMap((cabeceras) async {
      if (cabeceras.isEmpty) return const <Devolucion>[];

      final ids = cabeceras.map((c) => c.read<int>('id')).toList();
      final lineas = await _lineasDe(ids);

      return cabeceras
          .map((c) => DevolucionesMapper.cabeceraDesdeMapa(
                c.data,
                lineas[c.read<int>('id')] ?? const [],
              ))
          .toList();
    });
  }

  /// Todas las líneas de varias devoluciones en **una** consulta, agrupadas
  /// por documento. Una consulta por cabecera sería el N+1 de §5.
  Future<Map<int, List<DevolucionLinea>>> _lineasDe(List<int> ids) async {
    final marcas = List.filled(ids.length, '?').join(', ');
    final filas = await _db.customSelect(
      '''
      SELECT dd.id            AS id,
             dd.devolucion_id AS devolucion_id,
             dd.venta_detalle_id AS venta_detalle_id,
             dd.cantidad      AS cantidad,
             dd.precio_unitario AS precio_unitario,
             vd.producto_id   AS producto_id,
             vd.descripcion   AS descripcion
      FROM devolucion_detalles dd
      INNER JOIN venta_detalles vd ON vd.id = dd.venta_detalle_id
      WHERE dd.devolucion_id IN ($marcas)
      ORDER BY dd.id
      ''',
      variables: ids.map(Variable.withInt).toList(),
      readsFrom: _tablasDelModulo,
    ).get();

    final porDocumento = <int, List<DevolucionLinea>>{};
    for (final f in filas) {
      porDocumento
          .putIfAbsent(f.read<int>('devolucion_id'), () => [])
          .add(DevolucionesMapper.lineaDesdeMapa(f.data));
    }
    return porDocumento;
  }

  @override
  Future<Map<int, int>> descuadres() async {
    // El caché contra la suma de sus líneas, en un solo `GROUP BY`. El
    // `LEFT JOIN` incluye a las devoluciones sin líneas: una de esas con
    // total distinto de cero también está descuadrada.
    final filas = await _db.customSelect(
      '''
      SELECT d.id AS id,
             d.total - COALESCE(SUM(dd.cantidad * dd.precio_unitario), 0)
               AS diferencia
      FROM devoluciones d
      LEFT JOIN devolucion_detalles dd ON dd.devolucion_id = d.id
      GROUP BY d.id
      HAVING ABS(diferencia) > 0
      ''',
      readsFrom: {_tabla, _detalles},
    ).get();

    return {
      for (final f in filas) f.read<int>('id'): f.read<double>('diferencia').round(),
    };
  }

  // Escritura

  @override
  Future<Resultado> registrar({
    required int ventaId,
    required MotivoDevolucion motivo,
    required List<LineaADevolver> lineas,
    bool? reingresaStock,
    String? notas,
  }) async {
    // Quien puede anular la venta entera puede devolver una parte: es
    // estrictamente menos. La compuerta que vale es esta, no el botón
    // escondido (`CLAUDE.md` §7 bis).
    exigir(Permiso.posAnular);

    if (lineas.isEmpty) {
      return const Fallo(
        MotivoFallo.validacion,
        'No hay nada que devolver: elige al menos una línea.',
      );
    }

    // Sin decisión explícita manda el motivo: quien llame desde un test o
    // desde un flujo que no pregunte no tiene por qué acordarse de esto.
    final repone = reingresaStock ?? motivo.reponeStockPorDefecto;

    try {
      return await _db.transaction(() async {
        final venta = await (_db.select(_db.tablaVentas)
              ..where((v) => v.id.equals(ventaId)))
            .getSingleOrNull();

        if (venta == null) {
          return Fallo(
            MotivoFallo.validacion,
            'La venta #$ventaId ya no existe.',
          );
        }
        if (venta.estadoPago == 'ANULADA') {
          return Fallo(
            MotivoFallo.validacion,
            'La venta ${venta.numeroFactura} está anulada: ya se devolvió '
            'todo lo que quedaba.',
          );
        }

        final devolvibles = {
          for (final l in await lineasDevolvibles(ventaId)) l.ventaDetalleId: l,
        };

        // Se valida todo antes de escribir nada: la guarda de la base es la
        // red, pero su mensaje no se le puede enseñar a nadie.
        var total = 0;
        for (final pedida in lineas) {
          final linea = devolvibles[pedida.ventaDetalleId];
          if (linea == null) {
            return Fallo(
              MotivoFallo.validacion,
              'Una de las líneas no pertenece a la factura '
              '${venta.numeroFactura}.',
            );
          }
          if (pedida.cantidad <= 0) {
            return Fallo(
              MotivoFallo.validacion,
              'La cantidad a devolver de «${linea.descripcion}» tiene que ser '
              'mayor que cero.',
            );
          }
          if (pedida.cantidad > linea.disponible + _epsilon) {
            return Fallo(
              MotivoFallo.validacion,
              'De «${linea.descripcion}» solo quedan '
              '${_cantidad(linea.disponible)} por devolver.',
            );
          }
          total += (pedida.cantidad * linea.precioUnitario).round();
        }

        if (total <= 0) {
          return const Fallo(
            MotivoFallo.validacion,
            'La devolución no suma nada: revisa las cantidades.',
          );
        }

        // El número se pide **dentro** de la transacción: si algo falla más
        // abajo, vuelve a la serie en vez de dejar un hueco (§7.1).
        final numero =
            await _consecutivos.siguiente(DocumentoConsecutivo.devolucion);

        final devolucionId = await _db.into(_tabla).insert(
              TablaDevolucionCompanion.insert(
                numero: numero,
                ventaId: ventaId,
                motivo: motivo.codigo,
                reingresaStock: Value(repone),
                total: total,
                notas: Value(notas?.trim().isEmpty ?? true ? null : notas!.trim()),
                usuarioId: autorId,
              ),
            );

        final movimientos = <SolicitudMovimiento>[];
        for (final pedida in lineas) {
          final linea = devolvibles[pedida.ventaDetalleId]!;

          await _db.into(_detalles).insert(
                DevolucionesMapper.detalleACompanion(
                  devolucionId: devolucionId,
                  ventaDetalleId: pedida.ventaDetalleId,
                  cantidad: pedida.cantidad,
                  precioUnitario: linea.precioUnitario,
                ),
              );

          // Dos razones para no mover inventario, y son distintas: un
          // servicio prestado no vuelve a ninguna estantería, y una pieza rota
          // sí volvió al mostrador pero no al estante —se le reclama al
          // proveedor—. En las dos se devuelve la plata igual.
          if (repone && linea.productoId != null) {
            movimientos.add(
              SolicitudMovimiento.entrada(
                productoId: linea.productoId!,
                cantidad: pedida.cantidad,
                tipo: TipoMovimiento.devolucionVenta,
                ventaId: ventaId,
                notas: 'Devolución $numero — ${motivo.etiqueta}',
              ),
            );
          }
        }

        await _inventario.registrarVarios(movimientos);

        // La bitácora cuelga de la **venta**, que es lo que alguien va a
        // buscar: «¿qué pasó con la factura FAC-0012?».
        await _bitacora.anotar(
          Anotacion(
            entidad: EntidadAuditada.venta,
            accion: AccionAuditada.devolvio,
            entidadId: ventaId,
            descripcion: 'Venta ${venta.numeroFactura}',
            detalle: '$numero — ${motivo.etiqueta}. Total: $total'
                '${repone ? '' : ' (no volvió al inventario)'}',
          ),
        );

        return const Exito();
      });
    } on Exception catch (e) {
      // Aquí caen las guardas de la base: la que impide pasarse de lo vendido
      // y la que rechaza devolver sobre una venta anulada.
      return Fallo(MotivoFallo.persistencia, 'No se pudo registrar la devolución: $e');
    }
  }

  /// Sin decimales cuando no hacen falta: «2», no «2.0».
  static String _cantidad(double valor) =>
      valor % 1 == 0 ? valor.toInt().toString() : valor.toStringAsFixed(2);
}
