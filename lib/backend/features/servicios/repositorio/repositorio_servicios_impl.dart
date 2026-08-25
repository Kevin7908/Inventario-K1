import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../mapper/servicio_mapper.dart';
import '../modelo/servicio.dart';
import 'repositorio_servicios.dart';
import '../../../share/dominio/sesion_actual.dart';
import '../../bitacora/modelo/entrada_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora_impl.dart';
import '../../../share/dominio/permiso.dart';

class RepositorioServiciosImpl with FirmaDeSesion implements RepositorioServicios {
  RepositorioServiciosImpl(this._db, this.sesion);

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
          entidad: EntidadAuditada.servicio,
          accion: accion,
          entidadId: id,
          descripcion: descripcion,
          detalle: detalle,
        ),
      );


  final AppDb _db;

  // Alias conveniente al getter generado por Drift.
  $TablaServicioTable get _tabla => _db.tablaServicio;

  @override
  Stream<List<Servicio>> observarTodos() {
    return (_db.select(_tabla)
          ..orderBy([
            (t) => OrderingTerm(expression: t.activo, mode: OrderingMode.desc),
            (t) => OrderingTerm.asc(t.nombre),
          ]))
        .watch()
        .map(ServicioMapper.desdeFilas);
  }

  @override
  Future<List<Servicio>> obtenerTodos() async {
    final filas = await (_db.select(_tabla)
          ..orderBy([
            (t) => OrderingTerm(expression: t.activo, mode: OrderingMode.desc),
            (t) => OrderingTerm.asc(t.nombre),
          ]))
        .get();
    return ServicioMapper.desdeFilas(filas);
  }

  // Validacion 

  @override
  Future<bool> existeNombre(String nombre, {int? ignorarId}) async {
    final query = _db.select(_tabla)
      ..where((t) => t.nombre.lower().equals(nombre.toLowerCase()));

    if (ignorarId != null) {
      query.where((t) => t.id.isNotValue(ignorarId));
    }

    return (await query.getSingleOrNull()) != null;
  }

  @override
  Future<Servicio> agregar({
    required String nombre,
    String? descripcion,
    int precioSugerido = 0,
    bool activo = true,
  }) async {
    final companion = ServicioMapper.aCompanionNuevo(
      nombre: nombre.trim(),
      descripcion: descripcion?.trim(),
      precioSugerido: precioSugerido,
      activo: activo,
    );
    return _db.transaction(() async {
      final id = await _db.into(_tabla).insert(companion);
      await _anotar(AccionAuditada.creo, id, nombre.trim());
      return _porId(id);
    });
  }

  @override
  Future<Servicio> actualizar({
    required int id,
    required String nombre,
    String? descripcion,
    int precioSugerido = 0,
    required bool activo,
  }) async {
    final companion = ServicioMapper.aCompanionActualizar(
      id: id,
      nombre: nombre.trim(),
      descripcion: descripcion?.trim(),
      precioSugerido: precioSugerido,
      activo: activo,
    );
    return _db.transaction(() async {
      await (_db.update(_tabla)..where((t) => t.id.equals(id))).write(companion);
      await _anotar(AccionAuditada.modifico, id, nombre.trim());
      return _porId(id);
    });
  }

  @override
  Future<void> eliminar(int id) {
    exigir(Permiso.configuracionEditar);
    return _db.transaction(() async {
      final antes = await (_db.select(_tabla)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

      final eliminados =
          await (_db.delete(_tabla)..where((t) => t.id.equals(id))).go();
      if (eliminados == 0) {
        throw Exception('No se encontro el servicio con id $id.');
      }

      await _anotar(
        AccionAuditada.elimino,
        id,
        antes?.nombre ?? 'Servicio #$id',
      );
    });
  }

  @override
  Future<void> alternarActivo(int id, {required bool activo}) async {
    await (_db.update(_tabla)..where((t) => t.id.equals(id)))
        .write(TablaServicioCompanion(activo: Value(activo)));
  }

  // Helper privado

  Future<Servicio> _porId(int id) async {
    final fila =
        await (_db.select(_tabla)..where((t) => t.id.equals(id))).getSingle();
    return ServicioMapper.desdeFila(fila);
  }
}