import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/motos/repositorio/repositorio_motos.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../mapper/moto_mapper.dart';
import '../modelo/moto.dart';
import '../../../share/dominio/sesion_actual.dart';
import '../../bitacora/modelo/entrada_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora_impl.dart';
import '../../../share/dominio/permiso.dart';

class RepositorioMotosImpl with FirmaDeSesion implements RepositorioMotos {
  final AppDb _db;

  RepositorioMotosImpl(this._db, this.sesion);

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
  ]);
}

  Moto _rowToMoto(TypedResult row) {
    final motoData = row.readTable(_db.tablaMoto);
    final dueno = row.readTableOrNull(_db.tablaPersona);
    final nombreCliente = dueno != null
        ? '${dueno.nombres} ${dueno.apellidos ?? ''}'.trim()
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
    final p = _db.tablaPersona;
    return m.marca.lower().like(patron) |
        m.modelo.lower().like(patron) |
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
      leftOuterJoin(
        _db.tablaPersona,
        _db.tablaPersona.id.equalsExp(_db.tablaCliente.personaId),
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
  Future<int> crear(Moto moto) {
    exigir(Permiso.clientesEditar);
    return _db.transaction(() async {
      final companion = MotoMapper.modeloACompanion(moto);
      final id = await _db.into(_db.tablaMoto).insert(companion);
      await _anotar(AccionAuditada.creo, id, _nombreDe(moto));
      return id;
    });
  }

  @override
  Future<void> actualizar(Moto moto) {
    exigir(Permiso.clientesEditar);
    return _db.transaction(() async {
      final companion = MotoMapper.modeloACompanion(moto);
      await (_db.update(_db.tablaMoto)
            ..where((t) => t.id.equals(moto.id)))
          .write(companion);
      await _anotar(AccionAuditada.modifico, moto.id, _nombreDe(moto));
    });
  }

  @override
  Future<void> eliminar(int id) {
    exigir(Permiso.clientesEliminar);
    return _db.transaction(() async {
      final antes = await (_db.select(_db.tablaMoto)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();

      await (_db.delete(_db.tablaMoto)..where((t) => t.id.equals(id))).go();

      await _anotar(
        AccionAuditada.elimino,
        id,
        antes == null
            ? 'Moto #$id'
            : '${antes.marca} ${antes.modelo} (${antes.placa})',
      );
    });
  }

  /// Cómo se lee una moto en la bitácora: la placa es lo que la identifica.
  static String _nombreDe(Moto moto) =>
      '${moto.marca} ${moto.modelo} (${moto.placa})';
}