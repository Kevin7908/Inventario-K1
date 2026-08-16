import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/clientes/repositorio/repositorio_cliente.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../../motos/mapper/moto_mapper.dart';
import '../../motos/modelo/moto.dart';
import '../mapper/cliente_mapper.dart';
import '../modelo/cliente.dart';

class RepositorioClientesImpl implements RepositorioClientes {
  RepositorioClientesImpl(this._db);

  final AppDb _db;

  $TablaClienteTable get _tabla => _db.tablaCliente;

  /// Estados de deuda que cuentan como saldo pendiente. `PAGADA` ya no debe
  /// nada e `INCOBRABLE` se dio por perdida: ninguna de las dos suma.
  static const _estadosConSaldo = "('ACTIVA','VENCIDA')";

  // Streams y consultas simples

  @override
  Stream<List<Cliente>> observarTodos() {
    return (_db.select(_tabla)..orderBy([(t) => OrderingTerm.asc(t.nombres)]))
        .watch()
        .map((filas) => filas.map(ClienteMapper.filaAModelo).toList());
  }

  @override
  Future<List<Cliente>> obtenerTodos() async {
    final filas = await (_db.select(_tabla)
          ..orderBy([(t) => OrderingTerm.asc(t.nombres)]))
        .get();
    return filas.map(ClienteMapper.filaAModelo).toList();
  }

  @override
  Future<List<Cliente>> buscar(String query) async {
    final filas = await (_db.select(_tabla)
          ..where((t) => _texto(query))
          ..orderBy([(t) => OrderingTerm.asc(t.nombres)]))
        .get();
    return filas.map(ClienteMapper.filaAModelo).toList();
  }

  @override
  Future<Cliente?> obtenerPorId(int id) async {
    final fila = await (_db.select(_tabla)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return fila == null ? null : ClienteMapper.filaAModelo(fila);
  }

  @override
  Future<bool> existeCedula(String cedula, {int? excluirId}) async {
    var consulta = _db.select(_tabla)..where((t) => t.cedula.equals(cedula));
    if (excluirId != null) {
      consulta = consulta..where((t) => t.id.isNotValue(excluirId));
    }
    return await consulta.getSingleOrNull() != null;
  }

  // Paginación — WHERE, COUNT y LIMIT los resuelve SQLite, no el frontend.

  /// Coincidencia de texto libre, compartida por la búsqueda puntual y por la
  /// página.
  ///
  /// Los campos opcionales son nullable: en esas filas el `LIKE` devuelve NULL
  /// y no false, pero en SQLite `TRUE OR NULL` sigue siendo TRUE, así que
  /// basta con que otro campo coincida.
  Expression<bool> _texto(String query) {
    final patron = '%${query.toLowerCase()}%';
    final t = _tabla;
    return t.nombres.lower().like(patron) |
        t.apellidos.lower().like(patron) |
        t.cedula.lower().like(patron) |
        t.telefono.lower().like(patron) |
        t.email.lower().like(patron) |
        t.ciudad.lower().like(patron);
  }

  /// Traduce [FiltroClientes] a una expresión que reusan la consulta de la
  /// página y la del total.
  Expression<bool> _condicion(FiltroClientes filtro) {
    Expression<bool> acumulado = const Constant(true);

    final busqueda = filtro.busqueda.trim();
    if (busqueda.isNotEmpty) acumulado = acumulado & _texto(busqueda);

    final activo = filtro.activo;
    if (activo != null) {
      acumulado = acumulado & _tabla.activo.equals(activo ? 1 : 0);
    }

    return acumulado;
  }

  @override
  Stream<PaginaClientes> observarPagina({
    required FiltroClientes filtro,
    required int pagina,
    required int tamano,
  }) {
    final condicion = _condicion(filtro);

    final consultaPagina = _db.select(_tabla)
      ..where((_) => condicion)
      ..orderBy([(t) => OrderingTerm.asc(t.nombres)])
      ..limit(tamano, offset: pagina * tamano);

    // El total va en su propia consulta: el `limit` no debe afectarlo.
    final total = _tabla.id.count();
    final consultaTotal = _db.selectOnly(_tabla)
      ..addColumns([total])
      ..where(condicion);

    return consultaPagina.watch().asyncMap((filas) async {
      final fila = await consultaTotal.getSingleOrNull();
      return PaginaClientes(
        items: filas.map(ClienteMapper.filaAModelo).toList(),
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
  Future<int> crear(Cliente cliente) =>
      _db.into(_tabla).insert(ClienteMapper.modeloACompanion(cliente));

  @override
  Future<void> actualizar(Cliente cliente) async {
    await (_db.update(_tabla)..where((t) => t.id.equals(cliente.id)))
        .write(ClienteMapper.modeloACompanion(cliente));
  }

  @override
  Future<void> eliminar(int id) async {
    await (_db.delete(_tabla)..where((t) => t.id.equals(id))).go();
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
