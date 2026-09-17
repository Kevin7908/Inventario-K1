import 'package:drift/drift.dart';

import '../../../../core/resultado.dart';
import '../../../share/database/app_db.dart';
import '../../../share/dominio/permiso.dart';
import '../../../share/dominio/sesion_actual.dart';
import '../modelo/compatibilidad.dart';
import 'repositorio_compatibilidades.dart';

class RepositorioCompatibilidadesImpl
    with FirmaDeSesion
    implements RepositorioCompatibilidades {
  RepositorioCompatibilidadesImpl(this._db, this.sesion);

  final AppDb _db;

  /// Quién firma lo que este repositorio escribe. La inyecta Riverpod por el
  /// constructor, no la busca en ningún registro global.
  @override
  final SesionActual? sesion;

  /// La marca se alcanza por dos caminos —directa cuando la línea es de marca,
  /// o a través del modelo cuando es de modelo—, así que la tabla entra dos
  /// veces en el JOIN con alias distintos. Se guardan como campos para que la
  /// consulta y la lectura de la fila usen **la misma** instancia: dos alias
  /// creados por separado no son la misma columna para `readTableOrNull`.
  late final $TablaMarcaMotoTable _marcaDirecta =
      _db.alias(_db.tablaMarcaMoto, 'marca_directa');
  late final $TablaMarcaMotoTable _marcaDelModelo =
      _db.alias(_db.tablaMarcaMoto, 'marca_del_modelo');

  /// El JOIN que traduce las dos FK a texto en una sola pasada.
  ///
  /// La marca se alcanza por dos caminos —directo cuando la línea es de marca,
  /// o a través del modelo cuando es de modelo—, así que la tabla entra dos
  /// veces con alias distintos. Sin eso habría que consultar la marca del
  /// modelo fila por fila, que es el N+1 que prohíbe §5.
  JoinedSelectStatement<HasResultSet, dynamic> _consulta(int productoId) {
    return _db.select(_db.tablaProductoCompatibilidad).join([
      leftOuterJoin(
        _marcaDirecta,
        _marcaDirecta.id.equalsExp(_db.tablaProductoCompatibilidad.marcaId),
      ),
      leftOuterJoin(
        _db.tablaModeloMoto,
        _db.tablaModeloMoto.id
            .equalsExp(_db.tablaProductoCompatibilidad.modeloId),
      ),
      leftOuterJoin(
        _marcaDelModelo,
        _marcaDelModelo.id.equalsExp(_db.tablaModeloMoto.marcaId),
      ),
    ])
      ..where(_db.tablaProductoCompatibilidad.productoId.equals(productoId))
      ..orderBy([
        // Las de marca primero: son las más generales y se leen como el
        // encabezado de las de modelo.
        OrderingTerm.desc(_db.tablaProductoCompatibilidad.marcaId),
        OrderingTerm.asc(_db.tablaModeloMoto.nombre),
      ]);
  }

  Compatibilidad _aModelo(TypedResult row) {
    final fila = row.readTable(_db.tablaProductoCompatibilidad);
    final modelo = row.readTableOrNull(_db.tablaModeloMoto);

    return Compatibilidad(
      id: fila.id,
      productoId: fila.productoId,
      marcaId: fila.marcaId,
      modeloId: fila.modeloId,
      marca: row.readTableOrNull(_marcaDirecta)?.nombre ??
          row.readTableOrNull(_marcaDelModelo)?.nombre ??
          '',
      modelo: modelo?.nombre,
      cilindraje: modelo?.cilindraje,
    );
  }

  @override
  Stream<List<Compatibilidad>> observarDeProducto(int productoId) =>
      _consulta(productoId)
          .watch()
          .map((filas) => filas.map(_aModelo).toList(growable: false));

  @override
  Future<List<Compatibilidad>> obtenerDeProducto(int productoId) async {
    final filas = await _consulta(productoId).get();
    return filas.map(_aModelo).toList(growable: false);
  }

  @override
  Future<Resultado> agregarMarca({
    required int productoId,
    required int marcaId,
  }) =>
      _agregar(productoId: productoId, marcaId: marcaId);

  @override
  Future<Resultado> agregarModelo({
    required int productoId,
    required int modeloId,
  }) =>
      _agregar(productoId: productoId, modeloId: modeloId);

  Future<Resultado> _agregar({
    required int productoId,
    int? marcaId,
    int? modeloId,
  }) =>
      intentar(() async {
        exigir(Permiso.productosEditar);

        // La `UNIQUE` de la tabla no cierra este caso: SQLite trata cada NULL
        // como distinto, así que dos filas `(7, NULL, 3)` no chocan entre sí.
        // Por eso la comprobación es aquí y no una red de seguridad.
        final repetida = await (_db.select(_db.tablaProductoCompatibilidad)
              ..where(
                (t) =>
                    t.productoId.equals(productoId) &
                    (marcaId != null
                        ? t.marcaId.equals(marcaId)
                        : t.modeloId.equals(modeloId!)),
              )
              ..limit(1))
            .getSingleOrNull();
        if (repetida != null) {
          return const Fallo(
            MotivoFallo.nombreDuplicado,
            'Ese producto ya está declarado como compatible con esa moto.',
          );
        }

        await _db.into(_db.tablaProductoCompatibilidad).insert(
              TablaProductoCompatibilidadCompanion.insert(
                productoId: productoId,
                marcaId: Value(marcaId),
                modeloId: Value(modeloId),
              ),
            );
        return const Exito();
      });

  @override
  Future<Resultado> eliminar(int compatibilidadId) => intentar(() async {
        exigir(Permiso.productosEditar);
        final borradas = await (_db.delete(_db.tablaProductoCompatibilidad)
              ..where((t) => t.id.equals(compatibilidadId)))
            .go();
        if (borradas == 0) {
          throw Exception('Esa compatibilidad ya no existe.');
        }
        return const Exito();
      });
}
