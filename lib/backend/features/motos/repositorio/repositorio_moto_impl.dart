import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/motos/repositorio/repositorio_motos.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../mapper/moto_mapper.dart';
import '../modelo/moto.dart';

class RepositorioMotosImpl implements RepositorioMotos {
  final AppDb _db;

  RepositorioMotosImpl(this._db);

JoinedSelectStatement<HasResultSet, dynamic> get _baseQuery {
  return _db.select(_db.tablaMoto).join([
    leftOuterJoin(
      _db.tablaCliente,
      _db.tablaCliente.id.equalsExp(_db.tablaMoto.clienteId),
    ),
  ]);
}

  Moto _rowToMoto(TypedResult row) {
    final motoData = row.readTable(_db.tablaMoto);
    final clienteData = row.readTableOrNull(_db.tablaCliente);
    final nombreCliente = clienteData != null
        ? '${clienteData.nombres} ${clienteData.apellidos ?? ''}'.trim()
        : null;
    return MotoMapper.filaAModelo(motoData, nombreCliente: nombreCliente);
  }

  // Stream reactivo (todos)

  @override
  Stream<List<Moto>> observarTodos() {
    return (_baseQuery
          ..orderBy([
            OrderingTerm.asc(_db.tablaMoto.marca),
            OrderingTerm.asc(_db.tablaMoto.modelo),
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
            OrderingTerm.asc(_db.tablaMoto.marca),
            OrderingTerm.asc(_db.tablaMoto.modelo),
          ]))
        .watch()
        .map((rows) => rows.map(_rowToMoto).toList());
  }

  // Consulta puntual

  @override
  Future<List<Moto>> obtenerTodos() async {
    final rows = await (_baseQuery
          ..orderBy([
            OrderingTerm.asc(_db.tablaMoto.marca),
            OrderingTerm.asc(_db.tablaMoto.modelo),
          ]))
        .get();
    return rows.map(_rowToMoto).toList();
  }

  @override
  Future<List<Moto>> obtenerPorCliente(int clienteId) async {
    final rows = await (_baseQuery
          ..where(_db.tablaMoto.clienteId.equals(clienteId))
          ..orderBy([
            OrderingTerm.asc(_db.tablaMoto.marca),
            OrderingTerm.asc(_db.tablaMoto.modelo),
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

  @override
  Future<Moto?> duenoDeVin(String vin, {int? excluirMotoId}) =>
      _dueno((t) => t.vin, vin, excluirMotoId: excluirMotoId);

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
            cliente_id,
            COUNT(*) AS cantidad,
            MIN(marca || ' ' || modelo || COALESCE(' · ' || placa, '')) AS principal
          FROM motos
          WHERE activo = 1
          GROUP BY cliente_id
          ''',
          readsFrom: {_db.tablaMoto},
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
    final c = _db.tablaCliente;
    return m.marca.lower().like(patron) |
        m.modelo.lower().like(patron) |
        m.placa.lower().like(patron) |
        m.color.lower().like(patron) |
        m.vin.lower().like(patron) |
        c.nombres.lower().like(patron) |
        c.apellidos.lower().like(patron);
  }

  /// Traduce [FiltroMotos] a una expresión que reusan la consulta de la página
  /// y la del total.
  Expression<bool> _condicion(FiltroMotos filtro) {
    Expression<bool> acumulado = const Constant(true);

    final busqueda = filtro.busqueda.trim();
    if (busqueda.isNotEmpty) acumulado = acumulado & _texto(busqueda);

    final activo = filtro.activo;
    if (activo != null) {
      acumulado = acumulado & _db.tablaMoto.activo.equals(activo ? 1 : 0);
    }

    return acumulado;
  }

  /// Orden del catálogo. El `id` va al final para desempatar: dos motos con la
  /// misma marca y modelo tendrían un orden arbitrario, y con `LIMIT`/`OFFSET`
  /// eso hace que una fila se repita en dos páginas o no salga en ninguna.
  List<OrderingTerm> get _orden => [
        OrderingTerm.asc(_db.tablaMoto.marca),
        OrderingTerm.asc(_db.tablaMoto.modelo),
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

  @override
  Future<int> crear(Moto moto) async {
    final companion = MotoMapper.modeloACompanion(moto);
    return _db.into(_db.tablaMoto).insert(companion);
  }

  @override
  Future<void> actualizar(Moto moto) async {
    final companion = MotoMapper.modeloACompanion(moto);
    await (_db.update(_db.tablaMoto)
          ..where((t) => t.id.equals(moto.id)))
        .write(companion);
  }

  @override
  Future<void> eliminar(int id) async {
    await (_db.delete(_db.tablaMoto)..where((t) => t.id.equals(id))).go();
  }
}