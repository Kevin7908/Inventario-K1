import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/motos/repositorio/repositorio_motos.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../mapper/moto_mapper.dart';
import '../modelo/moto.dart';
import 'repositorio_marcas_moto.dart';
import 'repositorio_marcas_moto_impl.dart';
import '../../../share/dominio/sesion_actual.dart';
import '../../bitacora/modelo/entrada_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora_impl.dart';
import '../../../share/dominio/permiso.dart';

class RepositorioMotosImpl with FirmaDeSesion implements RepositorioMotos {
  final AppDb _db;

  RepositorioMotosImpl(this._db, this.sesion, {RepositorioMarcasMoto? marcas})
      : _marcas = marcas ?? RepositorioMarcasMotoImpl(_db, sesion);

  /// El catálogo de marcas y modelos, para traducir a id lo que se teclea.
  ///
  /// Se puede inyectar —un test le pasa el que quiera— y por defecto se arma
  /// con la misma base y la misma sesión: es una dependencia visible en el
  /// constructor, no algo que esta clase vaya a buscar a un registro
  /// (`CLAUDE.md` §3).
  final RepositorioMarcasMoto _marcas;

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
          entidad: EntidadAuditada.moto,
          accion: accion,
          entidadId: id,
          descripcion: descripcion,
          detalle: detalle,
        ),
      );


  /// El JOIN que resuelve todo lo que la vista necesita de una moto en una
  /// sola pasada: su dueño y su marca/modelo del catálogo.
  ///
  /// Traer las cuatro tablas juntas es lo que evita el N+1 (`REGLAS_BD.md`
  /// §5): con las FK en `motos`, pedir el nombre de la marca fila por fila
  /// sería una consulta por cada moto listada.
  JoinedSelectStatement<HasResultSet, dynamic> get _baseQuery {
    return _db.select(_db.tablaMoto).join([
      leftOuterJoin(
        _db.tablaCliente,
        _db.tablaCliente.id.equalsExp(_db.tablaMoto.clienteId),
      ),
      // El nombre del dueño vive en `personas`, no en `clientes`.
      leftOuterJoin(
        _db.tablaPersona,
        _db.tablaPersona.id.equalsExp(_db.tablaCliente.personaId),
      ),
      // `innerJoin` para la marca: su FK es `NOT NULL`, así que la fila
      // siempre está. El modelo va `leftOuterJoin` porque puede faltar.
      innerJoin(
        _db.tablaMarcaMoto,
        _db.tablaMarcaMoto.id.equalsExp(_db.tablaMoto.marcaId),
      ),
      leftOuterJoin(
        _db.tablaModeloMoto,
        _db.tablaModeloMoto.id.equalsExp(_db.tablaMoto.modeloId),
      ),
    ]);
  }

  Moto _rowToMoto(TypedResult row) {
    final motoData = row.readTable(_db.tablaMoto);
    final dueno = row.readTableOrNull(_db.tablaPersona);
    final nombreCliente = dueno != null
        ? '${dueno.nombres} ${dueno.apellidos ?? ''}'.trim()
        : null;
    final modelo = row.readTableOrNull(_db.tablaModeloMoto);
    return MotoMapper.filaAModelo(
      motoData,
      nombreCliente: nombreCliente,
      marca: row.readTable(_db.tablaMarcaMoto).nombre,
      modelo: modelo?.nombre,
      cilindraje: modelo?.cilindraje,
    );
  }

  // Stream reactivo (todos)

  @override
  Stream<List<Moto>> observarTodos() {
    return (_baseQuery
          ..orderBy([
            OrderingTerm.asc(_db.tablaMarcaMoto.nombre),
            OrderingTerm.asc(_db.tablaModeloMoto.nombre),
          ]))
        .watch()
        .map((rows) => rows.map(_rowToMoto).toList());
  }

  //Stream reactivo (por cliente) 

  @override
  Stream<List<Moto>> observarPorCliente(int clienteId) {
    return (_baseQuery
          ..where(_db.tablaMoto.clienteId.equals(clienteId))
          ..orderBy([
            OrderingTerm.asc(_db.tablaMarcaMoto.nombre),
            OrderingTerm.asc(_db.tablaModeloMoto.nombre),
          ]))
        .watch()
        .map((rows) => rows.map(_rowToMoto).toList());
  }

  // Consulta puntual

  @override
  Future<List<Moto>> obtenerTodos() async {
    final rows = await (_baseQuery
          ..orderBy([
            OrderingTerm.asc(_db.tablaMarcaMoto.nombre),
            OrderingTerm.asc(_db.tablaModeloMoto.nombre),
          ]))
        .get();
    return rows.map(_rowToMoto).toList();
  }

  @override
  Future<List<Moto>> obtenerPorCliente(int clienteId) async {
    final rows = await (_baseQuery
          ..where(_db.tablaMoto.clienteId.equals(clienteId))
          ..orderBy([
            OrderingTerm.asc(_db.tablaMarcaMoto.nombre),
            OrderingTerm.asc(_db.tablaModeloMoto.nombre),
          ]))
        .get();
    return rows.map(_rowToMoto).toList();
  }

  // Unicidad — quién es el dueño actual de una placa o un chasis

  /// Resuelve el dueño de un campo único (placa o VIN).
  ///
  /// La comparación es sin distinguir mayúsculas porque las placas se teclean
  /// de cualquier forma y "kmn12c" y "KMN12C" son la misma moto; el índice
  /// `unique` de la tabla, en cambio, sí distingue, así que sin esto la
  /// duplicada entraría.
  Future<Moto?> _dueno(
    GeneratedColumn<String> Function($TablaMotoTable t) campo,
    String valor, {
    int? excluirMotoId,
  }) async {
    final normalizado = valor.trim().toLowerCase();
    if (normalizado.isEmpty) return null;

    final columna = campo(_db.tablaMoto);
    var consulta = _baseQuery
      ..where(columna.lower().equals(normalizado));
    if (excluirMotoId != null) {
      consulta = consulta..where(_db.tablaMoto.id.isNotValue(excluirMotoId));
    }

    final fila = await consulta.getSingleOrNull();
    return fila == null ? null : _rowToMoto(fila);
  }

  @override
  Future<Moto?> duenoDePlaca(String placa, {int? excluirMotoId}) =>
      _dueno((t) => t.placa, placa, excluirMotoId: excluirMotoId);

  // Resumen por cliente

  @override
  Stream<Map<int, ResumenMotosCliente>> observarResumenPorCliente() {
    // `MIN` sobre la etiqueta ya concatenada devuelve la primera moto en el
    // mismo orden alfabético que `observarPorCliente` (marca y luego modelo),
    // y es determinista — una columna suelta dentro de un GROUP BY no lo
    // sería.
    return _db
        .customSelect(
          '''
          SELECT
            mo.cliente_id,
            COUNT(*) AS cantidad,
            MIN(
              ma.nombre
              || COALESCE(' ' || md.nombre, '')
              || COALESCE(' · ' || mo.placa, '')
            ) AS principal
          FROM motos mo
          JOIN marcas_moto ma ON ma.id = mo.marca_id
          LEFT JOIN modelos_moto md ON md.id = mo.modelo_id
          WHERE mo.activo = 1
          GROUP BY mo.cliente_id
          ''',
          // Las tres tablas van en `readsFrom`: si falta una, renombrar una
          // marca no vuelve a emitir y la lista se queda con el nombre viejo.
          readsFrom: {_db.tablaMoto, _db.tablaMarcaMoto, _db.tablaModeloMoto},
        )
        .watch()
        .map(
          (filas) => {
            for (final fila in filas)
              fila.read<int>('cliente_id'): (
                cantidad: fila.read<int>('cantidad'),
                principal: fila.read<String?>('principal'),
              ),
          },
        );
  }

  // Búsqueda

  /// Coincidencia de texto libre, compartida por la búsqueda puntual y por la
  /// página.
  ///
  /// Incluye las columnas del dueño porque el JOIN ya las trae y buscar
  /// "carlos" tiene que devolver sus motos. Se comparan por separado —y no
  /// concatenadas— igual que en `RepositorioClientesImpl._texto`.
  ///
  /// Los campos opcionales son nullable: en esas filas el `LIKE` devuelve NULL
  /// y no false, pero en SQLite `TRUE OR NULL` sigue siendo TRUE, así que
  /// basta con que otro campo coincida.
  Expression<bool> _texto(String query) {
    final patron = '%${query.toLowerCase()}%';
    final m = _db.tablaMoto;
    final p = _db.tablaPersona;
    // Marca y modelo se buscan en el catálogo, que es donde viven ahora.
    return _db.tablaMarcaMoto.nombre.lower().like(patron) |
        _db.tablaModeloMoto.nombre.lower().like(patron) |
        m.placa.lower().like(patron) |
        m.color.lower().like(patron) |
        p.nombres.lower().like(patron) |
        p.apellidos.lower().like(patron);
  }

  /// Traduce [FiltroMotos] a una expresión que reusan la consulta de la página
  /// y la del total.
  Expression<bool> _condicion(FiltroMotos filtro) {
    Expression<bool> acumulado = const Constant(true);

    final busqueda = filtro.busqueda.trim();
    if (busqueda.isNotEmpty) acumulado = acumulado & _texto(busqueda);

    final activo = filtro.activo;
    if (activo != null) {
      acumulado = acumulado & _db.tablaMoto.activo.equals(activo);
    }

    return acumulado;
  }

  /// Orden del catálogo. El `id` va al final para desempatar: dos motos con la
  /// misma marca y modelo tendrían un orden arbitrario, y con `LIMIT`/`OFFSET`
  /// eso hace que una fila se repita en dos páginas o no salga en ninguna.
  List<OrderingTerm> get _orden => [
        OrderingTerm.asc(_db.tablaMarcaMoto.nombre),
        OrderingTerm.asc(_db.tablaModeloMoto.nombre),
        OrderingTerm.asc(_db.tablaMoto.id),
      ];

  @override
  Future<List<Moto>> buscar(String query) async {
    final rows =
        await (_baseQuery..where(_texto(query))..orderBy(_orden)).get();
    return rows.map(_rowToMoto).toList();
  }

  // Paginación — WHERE, COUNT y LIMIT los resuelve SQLite, no el frontend.

  @override
  Stream<PaginaMotos> observarPagina({
    required FiltroMotos filtro,
    required int pagina,
    required int tamano,
  }) {
    final condicion = _condicion(filtro);

    final consultaPagina = _baseQuery
      ..where(condicion)
      ..orderBy(_orden)
      ..limit(tamano, offset: pagina * tamano);

    // El total va en su propia consulta: el `limit` no debe afectarlo. Repite
    // el JOIN porque el filtro puede mirar columnas del dueño.
    final total = _db.tablaMoto.id.count();
    final consultaTotal = _db.selectOnly(_db.tablaMoto).join([
      leftOuterJoin(
        _db.tablaCliente,
        _db.tablaCliente.id.equalsExp(_db.tablaMoto.clienteId),
      ),
      leftOuterJoin(
        _db.tablaPersona,
        _db.tablaPersona.id.equalsExp(_db.tablaCliente.personaId),
      ),
      // Los mismos dos del catálogo: el filtro de texto busca por marca y por
      // modelo, así que sin ellos el total no cuadraría con la página.
      innerJoin(
        _db.tablaMarcaMoto,
        _db.tablaMarcaMoto.id.equalsExp(_db.tablaMoto.marcaId),
      ),
      leftOuterJoin(
        _db.tablaModeloMoto,
        _db.tablaModeloMoto.id.equalsExp(_db.tablaMoto.modeloId),
      ),
    ])
      ..addColumns([total])
      ..where(condicion);

    return consultaPagina.watch().asyncMap((filas) async {
      final fila = await consultaTotal.getSingleOrNull();
      return PaginaMotos(
        items: filas.map(_rowToMoto).toList(),
        total: fila?.read(total) ?? 0,
      );
    });
  }

  @override
  Stream<ResumenMotos> observarResumen() {
    // Tres `COUNT` en una pasada, no tres consultas ni un recorrido en memoria.
    return _db
        .customSelect(
          '''
          SELECT
            COUNT(*) AS total,
            COUNT(*) FILTER (WHERE activo = 1) AS activas,
            COUNT(*) FILTER (WHERE placa IS NULL OR TRIM(placa) = '')
              AS sin_placa
          FROM motos
          ''',
          readsFrom: {_db.tablaMoto},
        )
        .watchSingleOrNull()
        .map(
          (fila) => (
            total: fila?.read<int>('total') ?? 0,
            activas: fila?.read<int>('activas') ?? 0,
            sinPlaca: fila?.read<int>('sin_placa') ?? 0,
          ),
        );
  }

  // Escritura 

  /// Traduce a ids lo que el formulario trae como texto, dando de alta en el
  /// catálogo lo que no esté.
  ///
  /// **Va aquí y no en la vista** porque normalizar es del repositorio
  /// (`REGLAS_BD.md` §2): los tres sitios que dan de alta motos —el catálogo,
  /// la ficha del cliente y el diálogo rápido de órdenes— pasan por esta
  /// misma resolución, así que ninguno puede colar una marca con otra caja.
  Future<Moto> _resolverCatalogo(Moto moto) async {
    final marcaId = await _marcas.asegurarMarca(moto.marca);
    final modeloId = await _marcas.asegurarModelo(
      marcaId: marcaId,
      nombre: moto.modelo,
      cilindraje: moto.cilindraje,
    );
    return moto.copyWith(marcaId: marcaId, modeloId: modeloId);
  }

  @override
  Future<int> crear(Moto moto) {
    exigir(Permiso.clientesEditar);
    return _db.transaction(() async {
      final resuelta = await _resolverCatalogo(moto);
      final id = await _db
          .into(_db.tablaMoto)
          .insert(MotoMapper.modeloACompanion(resuelta));
      await _anotar(AccionAuditada.creo, id, _nombreDe(resuelta));
      return id;
    });
  }

  @override
  Future<void> actualizar(Moto moto) {
    exigir(Permiso.clientesEditar);
    return _db.transaction(() async {
      final resuelta = await _resolverCatalogo(moto);
      await (_db.update(_db.tablaMoto)..where((t) => t.id.equals(moto.id)))
          .write(MotoMapper.modeloACompanion(resuelta));
      await _anotar(AccionAuditada.modifico, moto.id, _nombreDe(resuelta));
    });
  }

  @override
  Future<void> eliminar(int id) {
    exigir(Permiso.clientesEliminar);
    return _db.transaction(() async {
      // Se lee por el JOIN y no de la fila cruda: la marca y el modelo ya no
      // son columnas de `motos`, y la bitácora tiene que guardar el nombre
      // legible, que es la parte que sobrevive al borrado (§7.0).
      final antes = await (_baseQuery..where(_db.tablaMoto.id.equals(id)))
          .getSingleOrNull();
      final descripcion =
          antes == null ? 'Moto #$id' : _nombreDe(_rowToMoto(antes));

      await (_db.delete(_db.tablaMoto)..where((t) => t.id.equals(id))).go();

      await _anotar(AccionAuditada.elimino, id, descripcion);
    });
  }

  /// Cómo se lee una moto en la bitácora: la placa es lo que la identifica.
  static String _nombreDe(Moto moto) => moto.nombreDisplay;
}