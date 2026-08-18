import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../../persona/modelo/persona.dart';
import '../../persona/repositorio/repositorio_persona.dart';
import '../../persona/repositorio/repositorio_persona_impl.dart';
import '../mapper/proveedor_mapper.dart';
import '../modelo/proveedor.dart';
import 'repositorio_proveedores.dart';

class RepositorioProveedoresImpl implements RepositorioProveedores {
  RepositorioProveedoresImpl(this._db);

  final AppDb _db;

  late final RepositorioPersona _personas = RepositorioPersonaImpl(_db);

  $TablaProveedorTable get _tabla => _db.tablaProveedor;
  $TablaPersonaTable get _persona => _db.tablaPersona;

  /// `innerJoin` porque `persona_id` es obligatorio: un proveedor sin razón
  /// social no existe.
  JoinedSelectStatement<HasResultSet, dynamic> _conPersona() {
    return _db.select(_tabla).join([
      innerJoin(_persona, _persona.id.equalsExp(_tabla.personaId)),
    ]);
  }

  List<Proveedor> _mapear(List<TypedResult> filas) =>
      filas.map((f) => ProveedorMapper.filaJoinAModelo(f, _db)).toList();

  @override
  Stream<List<Proveedor>> observarTodas() =>
      (_conPersona()..orderBy([OrderingTerm.asc(_persona.nombres)]))
          .watch()
          .map(_mapear);

  @override
  Future<Proveedor?> obtenerPorId(int id) async {
    final fila =
        await (_conPersona()..where(_tabla.id.equals(id))).getSingleOrNull();
    return fila == null ? null : ProveedorMapper.filaJoinAModelo(fila, _db);
  }

  @override
  Future<List<Proveedor>> buscarPorNombre(String consulta) async => _mapear(
        await (_conPersona()
              ..where(_persona.nombres.lower().like('%${consulta.toLowerCase()}%')))
            .get(),
      );

  @override
  Future<Proveedor> crear(Proveedor proveedor) {
    // Persona y rol son dos filas: o entran las dos o no entra ninguna.
    return _db.transaction(() async {
      final personaId = await _personas.guardar(proveedor.datosPersona);
      final id = await _db.into(_tabla).insert(
            ProveedorMapper.modeloACompanion(proveedor, personaId: personaId),
          );
      return (await obtenerPorId(id))!;
    });
  }

  @override
  Future<Proveedor> actualizar(Proveedor proveedor) {
    return _db.transaction(() async {
      final personaId = await _personas.guardar(proveedor.datosPersona);
      await (_db.update(_tabla)..where((t) => t.id.equals(proveedor.id!))).write(
        ProveedorMapper.modeloACompanion(proveedor, personaId: personaId),
      );
      return (await obtenerPorId(proveedor.id!))!;
    });
  }

  @override
  Future<void> eliminar(int id) {
    return _db.transaction(() async {
      final fila = await (_db.selectOnly(_tabla)
            ..addColumns([_tabla.personaId])
            ..where(_tabla.id.equals(id)))
          .getSingleOrNull();
      final personaId = fila?.read(_tabla.personaId);

      await (_db.delete(_tabla)..where((t) => t.id.equals(id))).go();
      if (personaId != null) {
        await _personas.borrarSiQuedoSinRoles(personaId);
      }
    });
  }

  @override
  Future<bool> existeNombre(String nombre, {int? excludirId}) async {
    var condicion = _persona.nombres.lower().equals(nombre.toLowerCase());
    if (excludirId != null) {
      condicion = condicion & _tabla.id.isNotValue(excludirId);
    }
    return await (_conPersona()..where(condicion)).getSingleOrNull() != null;
  }

  @override
  Future<bool> existeNit(String nit, {int? excludirId}) async {
    final normalizado = normalizarDocumento(nit);
    if (normalizado == null) return false;

    var condicion = _persona.documento.equals(normalizado);
    if (excludirId != null) {
      condicion = condicion & _tabla.id.isNotValue(excludirId);
    }
    return await (_conPersona()..where(condicion)).getSingleOrNull() != null;
  }

  // Paginación — WHERE, COUNT y LIMIT los resuelve SQLite, no el frontend.

  /// Traduce [FiltroProveedores] a una expresión SQL reutilizable por la
  /// consulta de la página y por la del total.
  Expression<bool> _condicion(FiltroProveedores filtro) {
    Expression<bool> acumulado = const Constant(true);

    final texto = filtro.busqueda.trim();
    if (texto.isNotEmpty) {
      final patron = '%${texto.toLowerCase()}%';
      // NIT, ciudad y contacto son nullable: en esas filas el LIKE devuelve
      // NULL, no false. No hace falta `coalesce` porque en SQLite
      // `TRUE OR NULL` sigue siendo TRUE — basta con que otro campo coincida.
      acumulado = acumulado &
          (_persona.nombres.lower().like(patron) |
              _persona.documento.lower().like(patron) |
              _persona.ciudad.lower().like(patron) |
              _tabla.contacto.lower().like(patron));
    }

    final activo = filtro.activo;
    if (activo != null) acumulado = acumulado & _tabla.activo.equals(activo);

    return acumulado;
  }

  @override
  Stream<PaginaProveedores> observarPagina({
    required FiltroProveedores filtro,
    required int pagina,
    required int tamano,
  }) {
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
      return PaginaProveedores(
        items: _mapear(filas),
        total: fila?.read(total) ?? 0,
      );
    });
  }

  @override
  Stream<({int total, int activos})> observarResumen() {
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
