import 'package:drift/drift.dart';

import '../../../../core/resultado.dart';
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
  Future<Resultado> agregar({
    required String nombre,
    String? descripcion,
  }) =>
      intentar(() async {
        exigir(Permiso.configuracionEditar);
        final limpio = nombre.trim();
        if (limpio.isEmpty) {
          return const Fallo(
            MotivoFallo.validacion,
            'El nombre de la especialización no puede estar vacío.',
          );
        }
        if (await existeNombre(limpio)) {
          return const Fallo(
            MotivoFallo.nombreDuplicado,
            'Ya existe una especialización con ese nombre.',
          );
        }
        await _db.transaction(() async {
          final id = await _db.into(_tabla).insert(
                EspecializacionMapper.aCompanionNuevo(
                  nombre: limpio,
                  descripcion: descripcion?.trim(),
                ),
              );
          await _anotar(AccionAuditada.creo, id, limpio);
        });
        return const Exito();
      });

  @override
  Future<Resultado> actualizar({
    required int id,
    required String nombre,
    String? descripcion,
  }) =>
      intentar(() async {
        exigir(Permiso.configuracionEditar);
        final limpio = nombre.trim();
        if (limpio.isEmpty) {
          return const Fallo(
            MotivoFallo.validacion,
            'El nombre de la especialización no puede estar vacío.',
          );
        }
        if (await existeNombre(limpio, ignorarId: id)) {
          return const Fallo(
            MotivoFallo.nombreDuplicado,
            'Ya existe una especialización con ese nombre.',
          );
        }
        await _db.transaction(() async {
          final tocadas =
              await (_db.update(_tabla)..where((t) => t.id.equals(id))).write(
            EspecializacionMapper.aCompanionActualizar(
              id: id,
              nombre: limpio,
              descripcion: descripcion?.trim(),
            ),
          );
          if (tocadas == 0) {
            throw Exception('La especialización ya no existe.');
          }
          await _anotar(AccionAuditada.modifico, id, limpio);
        });
        return const Exito();
      });

  @override
  Future<Resultado> eliminar(int id) => intentar(() async {
        exigir(Permiso.configuracionEditar);
        await _db.transaction(() async {
          final antes =
              await (_db.select(_tabla)..where((t) => t.id.equals(id)))
                  .getSingleOrNull();

          final eliminadas =
              await (_db.delete(_tabla)..where((t) => t.id.equals(id))).go();
          if (eliminadas == 0) {
            throw Exception('La especialización ya no existe.');
          }

          await _anotar(
            AccionAuditada.elimino,
            id,
            antes?.nombre ?? 'Especialización #$id',
          );
        });
        return const Exito();
      });
}
