import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../../motos/mapper/moto_mapper.dart';
import '../../motos/modelo/moto.dart';
import '../../persona/modelo/persona.dart';
import '../../persona/repositorio/repositorio_persona.dart';
import '../../persona/repositorio/repositorio_persona_impl.dart';
import '../mapper/cliente_mapper.dart';
import '../modelo/cliente.dart';
import 'repositorio_cliente.dart';

class RepositorioClientesImpl implements RepositorioClientes {
  RepositorioClientesImpl(this._db);

  final AppDb _db;

  /// La identidad se escribe y se borra por aquí. No es service location: es
  /// una dependencia concreta del backend sobre el backend, creada a la vista.
  late final RepositorioPersona _personas = RepositorioPersonaImpl(_db);

  $TablaClienteTable get _tabla => _db.tablaCliente;
  $TablaPersonaTable get _persona => _db.tablaPersona;

  /// Estados de deuda que cuentan como saldo pendiente. `PAGADA` ya no debe
  /// nada e `INCOBRABLE` se dio por perdida: ninguna de las dos suma.
  static const _estadosConSaldo = "('ACTIVA','VENCIDA')";

  /// Un cliente son siempre dos filas. `innerJoin` y no `leftOuterJoin`
  /// porque `persona_id` es obligatorio: un cliente sin persona no existe.
  JoinedSelectStatement<HasResultSet, dynamic> _conPersona() {
    return _db.select(_tabla).join([
      innerJoin(_persona, _persona.id.equalsExp(_tabla.personaId)),
    ]);
  }

  List<Cliente> _mapear(List<TypedResult> filas) =>
      filas.map((f) => ClienteMapper.filaJoinAModelo(f, _db)).toList();

  // Streams y consultas simples

  @override
  Stream<List<Cliente>> observarTodos() =>
      (_conPersona()..orderBy([OrderingTerm.asc(_persona.nombres)]))
          .watch()
          .map(_mapear);

  @override
  Future<List<Cliente>> obtenerTodos() async => _mapear(
        await (_conPersona()..orderBy([OrderingTerm.asc(_persona.nombres)]))
            .get(),
      );

  @override
  Future<List<Cliente>> buscar(String query) async => _mapear(
        await (_conPersona()
              ..where(_texto(query))
              ..orderBy([OrderingTerm.asc(_persona.nombres)]))
            .get(),
      );

  @override
  Future<Cliente?> obtenerPorId(int id) async {
    final fila = await (_conPersona()..where(_tabla.id.equals(id)))
        .getSingleOrNull();
    return fila == null ? null : ClienteMapper.filaJoinAModelo(fila, _db);
  }

  @override
  Future<bool> existeDocumento(String documento, {int? excluirId}) async {
    final normalizado = normalizarDocumento(documento);
    if (normalizado == null) return false;

    var condicion = _persona.documento.equals(normalizado);
    if (excluirId != null) {
      condicion = condicion & _tabla.id.isNotValue(excluirId);
    }

    final fila = await (_conPersona()..where(condicion)).getSingleOrNull();
    return fila != null;
  }

  // Paginación — WHERE, COUNT y LIMIT los resuelve SQLite, no el frontend.

  /// Coincidencia de texto libre, compartida por la búsqueda puntual y por la
  /// página.
  ///
  /// Todos los campos salen de `personas`. Los opcionales son nullable: en
  /// esas filas el `LIKE` devuelve NULL y no false, pero en SQLite
  /// `TRUE OR NULL` sigue siendo TRUE, así que basta con que otro coincida.
  Expression<bool> _texto(String query) {
    final patron = '%${query.toLowerCase()}%';
    return _persona.nombres.lower().like(patron) |
        _persona.apellidos.lower().like(patron) |
        _persona.documento.lower().like(patron) |
        _persona.telefono.lower().like(patron) |
        _persona.email.lower().like(patron) |
        _persona.ciudad.lower().like(patron);
  }

  /// Traduce [FiltroClientes] a una expresión que reusan la consulta de la
  /// página y la del total.
  Expression<bool> _condicion(FiltroClientes filtro) {
    Expression<bool> acumulado = const Constant(true);

    final busqueda = filtro.busqueda.trim();
    if (busqueda.isNotEmpty) acumulado = acumulado & _texto(busqueda);

    final activo = filtro.activo;
    if (activo != null) acumulado = acumulado & _tabla.activo.equals(activo);

    return acumulado;
  }

  @override
  Stream<PaginaClientes> observarPagina({
    required FiltroClientes filtro,
    required int pagina,
    required int tamano,
  }) {
    final condicion = _condicion(filtro);

    final consultaPagina = _conPersona()
      ..where(condicion)
      ..orderBy([OrderingTerm.asc(_persona.nombres)])
      ..limit(tamano, offset: pagina * tamano);

    // El total va en su propia consulta: el `limit` no debe afectarlo.
    final total = _tabla.id.count();
    final consultaTotal = _db.selectOnly(_tabla)
      ..addColumns([total])
      ..join([innerJoin(_persona, _persona.id.equalsExp(_tabla.personaId))])
      ..where(condicion);

    return consultaPagina.watch().asyncMap((filas) async {
      final fila = await consultaTotal.getSingleOrNull();
      return PaginaClientes(
        items: _mapear(filas),
        total: fila?.read(total) ?? 0,
      );
    });
  }

  @override
  Stream<ResumenClientes> observarResumen() {
    // El total sale de `clientes`; el de "con saldo" cruza con `deudores`, así
    // que va en la misma consulta cruda para no abrir dos streams que habría
    // que combinar a mano.
    return _db
        .customSelect(
          '''
          SELECT
            COUNT(*) AS total,
            COUNT(*) FILTER (WHERE EXISTS (
              SELECT 1 FROM deudores d
              WHERE d.cliente_id = c.id
                AND d.estado IN $_estadosConSaldo
                AND d.monto_total > d.monto_pagado
            )) AS con_saldo
          FROM clientes c
          ''',
          readsFrom: {_tabla, _db.tablaDeudor},
        )
        .watchSingleOrNull()
        .map(
          (fila) => (
            total: fila?.read<int>('total') ?? 0,
            conSaldo: fila?.read<int>('con_saldo') ?? 0,
          ),
        );
  }

  @override
  Stream<Map<int, SaldoCliente>> observarSaldos() {
    // Un `GROUP BY` en SQL, no un recorrido de deudas en memoria. Se filtra
    // por `monto_total > monto_pagado` además de por estado para que una deuda
    // saldada pero aún marcada ACTIVA no deje al cliente en rojo.
    return _db
        .customSelect(
          '''
          SELECT
            cliente_id,
            SUM(monto_total - monto_pagado) AS pendiente,
            COUNT(*) AS deudas
          FROM deudores
          WHERE estado IN $_estadosConSaldo
            AND monto_total > monto_pagado
          GROUP BY cliente_id
          ''',
          readsFrom: {_db.tablaDeudor},
        )
        .watch()
        .map(
          (filas) => {
            for (final fila in filas)
              fila.read<int>('cliente_id'): (
                pendiente: fila.read<int>('pendiente'),
                deudas: fila.read<int>('deudas'),
              ),
          },
        );
  }

  // Escritura

  @override
  Future<int> crear(Cliente cliente) {
    // Persona y rol son dos filas: si la segunda falla, la primera no puede
    // quedar suelta.
    return _db.transaction(() async {
      final personaId = await _personas.guardar(cliente.datosPersona);
      return _db
          .into(_tabla)
          .insert(ClienteMapper.modeloACompanion(cliente, personaId: personaId));
    });
  }

  @override
  Future<void> actualizar(Cliente cliente) {
    return _db.transaction(() async {
      final personaId = await _personas.guardar(cliente.datosPersona);
      await (_db.update(_tabla)..where((t) => t.id.equals(cliente.id))).write(
        ClienteMapper.modeloACompanion(cliente, personaId: personaId),
      );
    });
  }

  @override
  Future<void> eliminar(int id) {
    return _db.transaction(() async {
      final personaId = await _personaIdDe(id);
      await (_db.delete(_tabla)..where((t) => t.id.equals(id))).go();
      if (personaId != null) {
        await _personas.borrarSiQuedoSinRoles(personaId);
      }
    });
  }

  Future<int?> _personaIdDe(int clienteId) async {
    final fila = await (_db.selectOnly(_tabla)
          ..addColumns([_tabla.personaId])
          ..where(_tabla.id.equals(clienteId)))
        .getSingleOrNull();
    return fila?.read(_tabla.personaId);
  }

  @override
  Future<int> guardarConMotos({
    required Cliente cliente,
    required List<Moto> motos,
  }) {
    return _db.transaction(() async {
      final clienteId = cliente.id == 0
          ? await crear(cliente)
          : await actualizar(cliente).then((_) => cliente.id);

      final motosTabla = _db.tablaMoto;

      // Lo que el cliente tiene hoy, para saber qué sobra al terminar.
      final previas = await (_db.selectOnly(motosTabla)
            ..addColumns([motosTabla.id])
            ..where(motosTabla.clienteId.equals(clienteId)))
          .map((fila) => fila.read(motosTabla.id)!)
          .get();

      final conservadas = <int>{};
      for (final moto in motos) {
        // El clienteId se fuerza aquí y no en el formulario: al crear todavía
        // no existe el id, y al editar no debe poder cambiarse por accidente.
        final companion =
            MotoMapper.modeloACompanion(moto.copyWith(clienteId: clienteId));

        if (moto.id == 0) {
          conservadas.add(await _db.into(motosTabla).insert(companion));
        } else {
          await (_db.update(motosTabla)..where((t) => t.id.equals(moto.id)))
              .write(companion);
          conservadas.add(moto.id);
        }
      }

      final sobrantes = previas.where((id) => !conservadas.contains(id));
      if (sobrantes.isNotEmpty) {
        await (_db.delete(motosTabla)..where((t) => t.id.isIn(sobrantes))).go();
      }

      return clienteId;
    });
  }
}
