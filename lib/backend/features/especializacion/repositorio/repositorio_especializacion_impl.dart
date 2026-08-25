import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../mapper/especializacion_mapper.dart';
import '../modelo/especializacion.dart';
import 'repositorio_especializacion.dart';
import '../../../share/dominio/sesion_actual.dart';
import '../../bitacora/modelo/entrada_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora_impl.dart';
import '../../../share/dominio/permiso.dart';

class RepositorioEspecializacionImpl with FirmaDeSesion implements RepositorioEspecializacion {
  RepositorioEspecializacionImpl(this._db, this.sesion);

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
          entidad: EntidadAuditada.especializacion,
          accion: accion,
          entidadId: id,
          descripcion: descripcion,
          detalle: detalle,
        ),
      );


  final AppDb _db;

  // Alias conveniente
  $TablaEspecializacionTable get _tabla => _db.tablaEspecializacion;

  // Stream reactivo 
  @override
  Stream<List<Especializacion>> observarTodas() {
    return (_db.select(_tabla)
          ..orderBy([(t) => OrderingTerm.asc(t.nombre)]))
        .watch()
        .map(EspecializacionMapper.desdeFilas);
  }

  @override
  Future<List<Especializacion>> obtenerTodas() async {
    final filas = await (_db.select(_tabla)
          ..orderBy([(t) => OrderingTerm.asc(t.nombre)]))
        .get();
    return EspecializacionMapper.desdeFilas(filas);
  }

  // Validación de nombre único 
  @override
  Future<bool> existeNombre(String nombre, {int? ignorarId}) async {
    final query = _db.select(_tabla)
      ..where(
        (t) => t.nombre.lower().equals(nombre.toLowerCase()),
      );

    if (ignorarId != null) {
      query.where((t) => t.id.isNotValue(ignorarId));
    }

    final fila = await query.getSingleOrNull();
    return fila != null;
  }

  // CRUD 
  @override
  Future<Especializacion> agregar({
    required String nombre,
    String? descripcion,
  }) async {
    final companion = EspecializacionMapper.aCompanionNuevo(
      nombre: nombre.trim(),
      descripcion: descripcion?.trim(),
    );
    return _db.transaction(() async {
      final id = await _db.into(_tabla).insert(companion);
      await _anotar(AccionAuditada.creo, id, nombre.trim());
      final fila = await (_db.select(_tabla)..where((t) => t.id.equals(id)))
          .getSingle();
      return EspecializacionMapper.desdeFila(fila);
    });
  }

  @override
  Future<Especializacion> actualizar({
    required int id,
    required String nombre,
    String? descripcion,
  }) async {
    final companion = EspecializacionMapper.aCompanionActualizar(
      id: id,
      nombre: nombre.trim(),
      descripcion: descripcion?.trim(),
    );
    return _db.transaction(() async {
      await (_db.update(_tabla)..where((t) => t.id.equals(id)))
          .write(companion);
      await _anotar(AccionAuditada.modifico, id, nombre.trim());
      final fila = await (_db.select(_tabla)..where((t) => t.id.equals(id)))
          .getSingle();
      return EspecializacionMapper.desdeFila(fila);
    });
  }

  @override
  Future<void> eliminar(int id) {
    exigir(Permiso.configuracionEditar);
    return _db.transaction(() async {
      final antes = await (_db.select(_tabla)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

      await (_db.delete(_tabla)..where((t) => t.id.equals(id))).go();

      await _anotar(
        AccionAuditada.elimino,
        id,
        antes?.nombre ?? 'Especialización #$id',
      );
    });
  }
}