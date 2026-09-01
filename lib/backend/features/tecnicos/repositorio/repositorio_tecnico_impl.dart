import 'dart:async';

import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../../persona/modelo/persona.dart';
import '../../persona/repositorio/repositorio_persona.dart';
import '../../persona/repositorio/repositorio_persona_impl.dart';
import '../mapper/tecnico_mapper.dart';
import '../modelo/tecnico.dart';
import 'repositorio_tecnico.dart';
import '../../../share/dominio/sesion_actual.dart';
import '../../bitacora/modelo/entrada_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora_impl.dart';
import '../../../share/dominio/permiso.dart';

final class RepositorioTecnicoDrift with FirmaDeSesion implements RepositorioTecnico {
  RepositorioTecnicoDrift(this._db, this.sesion);

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
          entidad: EntidadAuditada.tecnico,
          accion: accion,
          entidadId: id,
          descripcion: descripcion,
          detalle: detalle,
        ),
      );


  final AppDb _db;

  late final RepositorioPersona _personas = RepositorioPersonaImpl(_db);

  $TablaTecnicoTable get _tabla => _db.tablaTecnico;
  $TablaPersonaTable get _persona => _db.tablaPersona;

  /// `innerJoin` porque `persona_id` es obligatorio: un técnico sin persona no
  /// existe.
  JoinedSelectStatement<HasResultSet, dynamic> _conPersona() {
    return _db.select(_tabla).join([
      innerJoin(_persona, _persona.id.equalsExp(_tabla.personaId)),
    ]);
  }

  List<Tecnico> _mapear(List<TypedResult> filas) =>
      filas.map((f) => TecnicoMapper.desdeJoin(f, _db)).toList();

  @override
  Stream<List<Tecnico>> observarTodos() {
    exigir(Permiso.tecnicosVer);
    return (_conPersona()..orderBy([OrderingTerm.asc(_persona.nombres)]))
        .watch()
        .map(_mapear);
  }

  @override
  Future<bool> existeDocumento(String documento, {int? excluirId}) async {
    final normalizado = normalizarDocumento(documento);
    if (normalizado == null) return false;

    var condicion = _persona.documento.equals(normalizado);
    if (excluirId != null) {
      condicion = condicion & _tabla.id.isNotValue(excluirId);
    }

    return await (_conPersona()..where(condicion)).getSingleOrNull() != null;
  }

  Future<Tecnico?> _obtenerPorId(int id) async {
    final fila =
        await (_conPersona()..where(_tabla.id.equals(id))).getSingleOrNull();
    return fila == null ? null : TecnicoMapper.desdeJoin(fila, _db);
  }

  @override
  Future<Tecnico> crear(Tecnico tecnico) {
    exigir(Permiso.tecnicosEditar);
    // Persona y rol son dos filas: o entran las dos o no entra ninguna.
    return _db.transaction(() async {
      final personaId = await _personas.guardar(tecnico.datosPersona);
      final id = await _db
          .into(_tabla)
          .insert(TecnicoMapper.modeloACompanion(tecnico, personaId: personaId));
      await _anotar(AccionAuditada.creo, id, _nombreDe(tecnico));
      return (await _obtenerPorId(id))!;
    });
  }

  @override
  Future<Tecnico> actualizar(Tecnico tecnico) {
    exigir(Permiso.tecnicosEditar);
    return _db.transaction(() async {
      final personaId = await _personas.guardar(tecnico.datosPersona);
      await (_db.update(_tabla)..where((t) => t.id.equals(tecnico.id!))).write(
        TecnicoMapper.modeloACompanion(tecnico, personaId: personaId),
      );
      await _anotar(AccionAuditada.modifico, tecnico.id, _nombreDe(tecnico));
      return (await _obtenerPorId(tecnico.id!))!;
    });
  }

  @override
  Future<void> eliminar(int id) {
    exigir(Permiso.tecnicosEliminar);
    return _db.transaction(() async {
      final antes = await _obtenerPorId(id);
      final fila = await (_db.selectOnly(_tabla)
            ..addColumns([_tabla.personaId])
            ..where(_tabla.id.equals(id)))
          .getSingleOrNull();
      final personaId = fila?.read(_tabla.personaId);

      await (_db.delete(_tabla)..where((t) => t.id.equals(id))).go();
      if (personaId != null) {
        await _personas.borrarSiQuedoSinRoles(personaId);
      }

      await _anotar(
        AccionAuditada.elimino,
        id,
        antes == null ? 'Técnico #$id' : _nombreDe(antes),
      );
    });
  }

  /// Cómo se lee un técnico en la bitácora.
  static String _nombreDe(Tecnico tecnico) => [tecnico.nombres, tecnico.apellidos]
      .where((p) => p != null && p.trim().isNotEmpty)
      .join(' ');

  // Paginación — WHERE, COUNT y LIMIT los resuelve SQLite, no el frontend.

  /// Traduce [FiltroTecnicos] a una expresión SQL reutilizable por la
  /// consulta de la página y por la del total.
  Expression<bool> _condicion(FiltroTecnicos filtro) {
    Expression<bool> acumulado = const Constant(true);

    final texto = filtro.busqueda.trim();
    if (texto.isNotEmpty) {
      final patron = '%${texto.toLowerCase()}%';
      // Apellidos, documento y teléfono son nullable: en esas filas el LIKE
      // devuelve NULL, no false. No hace falta `coalesce` porque en SQLite
      // `TRUE OR NULL` sigue siendo TRUE — basta con que otro campo coincida.
      acumulado = acumulado &
          (_persona.nombres.lower().like(patron) |
              _persona.apellidos.lower().like(patron) |
              _persona.documento.lower().like(patron) |
              _persona.telefono.lower().like(patron));
    }

    final activo = filtro.activo;
    if (activo != null) acumulado = acumulado & _tabla.activo.equals(activo);

    return acumulado;
  }

  @override
  Stream<PaginaTecnicos> observarPagina({
    required FiltroTecnicos filtro,
    required int pagina,
    required int tamano,
  }) {
    exigir(Permiso.tecnicosVer);
    final condicion = _condicion(filtro);

    final consultaPagina = _conPersona()
      ..where(condicion)
      ..orderBy([OrderingTerm.asc(_persona.nombres)])
      ..limit(tamano, offset: pagina * tamano);

    // El total va en su propia consulta: `limit` no debe afectarlo.
    final total = _tabla.id.count();
    final consultaTotal = _db.selectOnly(_tabla)
      ..addColumns([total])
      ..join([innerJoin(_persona, _persona.id.equalsExp(_tabla.personaId))])
      ..where(condicion);

    return consultaPagina.watch().asyncMap((filas) async {
      final fila = await consultaTotal.getSingleOrNull();
      return PaginaTecnicos(
        items: _mapear(filas),
        total: fila?.read(total) ?? 0,
      );
    });
  }

  @override
  Stream<({int total, int activos})> observarResumen() {
    exigir(Permiso.tecnicosVer);
    final total = _tabla.id.count();
    final activos = _tabla.id.count(filter: _tabla.activo.equals(true));

    final consulta = _db.selectOnly(_tabla)..addColumns([total, activos]);

    return consulta.watchSingleOrNull().map(
          (fila) => (
            total: fila?.read(total) ?? 0,
            activos: fila?.read(activos) ?? 0,
          ),
        );
  }
}
