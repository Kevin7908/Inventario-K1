import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import '../modelo/unidad_medida.dart';
import 'repositorio_unidades_medida.dart';
import '../../../share/dominio/sesion_actual.dart';
import '../../bitacora/modelo/entrada_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora_impl.dart';
import '../../../share/dominio/permiso.dart';

class RepositorioUnidadesMedidaImpl with FirmaDeSesion implements RepositorioUnidadesMedida {
  final AppDb _db;

  RepositorioUnidadesMedidaImpl(this._db, this.sesion);

  /// Quién firma lo que este repositorio escribe. La inyecta Riverpod por el
  /// constructor, no la busca en ningún registro global.
  @override
  final SesionActual? sesion;

  late final RepositorioBitacora _bitacora =
      RepositorioBitacoraImpl(_db, sesion);

  /// Deja el renglón de la bitácora. Se llama **dentro** de la transacción del
  /// cambio: si la escritura se revierte, el renglón se va con ella.
  Future<void> _anotar(
    AccionAuditada accion,
    int? id,
    String descripcion, {
    String? detalle,
  }) =>
      _bitacora.anotar(
        Anotacion(
          entidad: EntidadAuditada.unidadMedida,
          accion: accion,
          entidadId: id,
          descripcion: descripcion,
          detalle: detalle,
        ),
      );


  UnidadMedida _filaAModelo(TablaUnidadesMedidaData fila) {
    return UnidadMedida(
      id: fila.id,
      nombre: fila.nombre,
      abreviatura: fila.abreviatura,
      tipo: fila.tipo,
      descripcion: fila.descripcion,
      creadoEn: fila.creadoEn,
      actualizadoEn: fila.actualizadoEn,
    );
  }

  TablaUnidadesMedidaCompanion _modeloACompanion(UnidadMedida unidad) {
    return TablaUnidadesMedidaCompanion(
      id: unidad.id != null ? Value(unidad.id!) : const Value.absent(),
      nombre: Value(unidad.nombre),
      abreviatura: Value(unidad.abreviatura),
      tipo: Value(unidad.tipo),
      descripcion: Value(unidad.descripcion),
      actualizadoEn: Value(DateTime.now()),
    );
  }

  @override
  Future<List<UnidadMedida>> obtenerTodas() async {
    final filas = await _db.select(_db.tablaUnidadesMedida).get();
    return filas.map(_filaAModelo).toList();
  }

  @override
  Future<UnidadMedida?> obtenerPorId(int id) async {
    final fila = await (_db.select(
      _db.tablaUnidadesMedida,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return fila != null ? _filaAModelo(fila) : null;
  }

  @override
  Future<List<UnidadMedida>> buscarPorNombre(String consulta) async {
    final filas = await (_db.select(
      _db.tablaUnidadesMedida,
    )..where((t) => t.nombre.like('%$consulta%'))).get();
    return filas.map(_filaAModelo).toList();
  }

  @override
  Future<List<UnidadMedida>> obtenerPorTipo(String tipo) async {
    final filas = await (_db.select(
      _db.tablaUnidadesMedida,
    )..where((t) => t.tipo.equals(tipo))).get();
    return filas.map(_filaAModelo).toList();
  }

  @override
  Future<UnidadMedida> crear(UnidadMedida unidad) {
    exigir(Permiso.configuracionEditar);
    return _db.transaction(() async {
      final companion = _modeloACompanion(unidad);
      final id = await _db.into(_db.tablaUnidadesMedida).insert(companion);
      await _anotar(AccionAuditada.creo, id, unidad.nombre);
      return (await obtenerPorId(id))!;
    });
  }

  @override
  Future<UnidadMedida> actualizar(UnidadMedida unidad) {
    exigir(Permiso.configuracionEditar);
    return _db.transaction(() async {
      final companion = _modeloACompanion(unidad);
      await (_db.update(
        _db.tablaUnidadesMedida,
      )..where((t) => t.id.equals(unidad.id!))).write(companion);
      await _anotar(AccionAuditada.modifico, unidad.id, unidad.nombre);
      return (await obtenerPorId(unidad.id!))!;
    });
  }

  @override
  Future<void> eliminar(int id) {
    exigir(Permiso.configuracionEditar);
    return _db.transaction(() async {
      final antes = await obtenerPorId(id);
      await (_db.delete(
        _db.tablaUnidadesMedida,
      )..where((t) => t.id.equals(id))).go();
      await _anotar(
        AccionAuditada.elimino,
        id,
        antes?.nombre ?? 'Unidad #$id',
      );
    });
  }

  @override
  Future<bool> existeNombre(String nombre, {int? excludirId}) async {
    final query = _db.select(_db.tablaUnidadesMedida)
      ..where((t) => t.nombre.lower().equals(nombre.toLowerCase()));
    if (excludirId != null) {
      query.where((t) => t.id.equals(excludirId).not());
    }
    return await query.getSingleOrNull() != null;
  }

  @override
  Future<bool> existeAbreviatura(String abreviatura, {int? excludirId}) async {
    final query = _db.select(_db.tablaUnidadesMedida)
      ..where((t) => t.abreviatura.lower().equals(abreviatura.toLowerCase()));
    if (excludirId != null) {
      query.where((t) => t.id.equals(excludirId).not());
    }
    return await query.getSingleOrNull() != null;
  }
}
