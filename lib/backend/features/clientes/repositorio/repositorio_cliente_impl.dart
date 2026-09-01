import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../../motos/mapper/moto_mapper.dart';
import '../../motos/modelo/moto.dart';
import '../../motos/repositorio/repositorio_marcas_moto.dart';
import '../../motos/repositorio/repositorio_marcas_moto_impl.dart';
import '../../persona/modelo/persona.dart';
import '../../persona/repositorio/repositorio_persona.dart';
import '../../persona/repositorio/repositorio_persona_impl.dart';
import '../mapper/cliente_mapper.dart';
import '../modelo/cliente.dart';
import 'repositorio_cliente.dart';
import '../../../share/dominio/sesion_actual.dart';
import '../../bitacora/modelo/entrada_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora_impl.dart';
import '../../../share/dominio/permiso.dart';

class RepositorioClientesImpl with FirmaDeSesion implements RepositorioClientes {
  RepositorioClientesImpl(
    this._db,
    this.sesion, {
    RepositorioMarcasMoto? marcas,
  }) : _marcas = marcas ?? RepositorioMarcasMotoImpl(_db, sesion);

  /// El catálogo de marcas y modelos, para traducir a id lo que se teclea en
  /// las motos del cliente. Es una dependencia del constructor, sustituible en
  /// un test (`CLAUDE.md` §3).
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
          entidad: EntidadAuditada.cliente,
          accion: accion,
          entidadId: id,
          descripcion: descripcion,
          detalle: detalle,
        ),
      );


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
  Stream<List<Cliente>> observarTodos() {
    exigir(Permiso.clientesVer);
    return (_conPersona()..orderBy([OrderingTerm.asc(_persona.nombres)]))
        .watch()
        .map(_mapear);
  }

  @override
  Future<List<Cliente>> obtenerTodos() async {
    exigir(Permiso.clientesVer);
    return _mapear(
      await (_conPersona()..orderBy([OrderingTerm.asc(_persona.nombres)]))
          .get(),
    );
  }

  @override
  Future<List<Cliente>> buscar(String query) async {
    exigir(Permiso.clientesVer);
    return _mapear(
      await (_conPersona()
            ..where(_texto(query))
            ..orderBy([OrderingTerm.asc(_persona.nombres)]))
          .get(),
    );
  }

  @override
  Future<Cliente?> obtenerPorId(int id) async {
    exigir(Permiso.clientesVer);
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
    exigir(Permiso.clientesVer);
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
    exigir(Permiso.clientesVer);
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
    exigir(Permiso.clientesVer);
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
    exigir(Permiso.clientesEditar);
    // Persona y rol son dos filas: si la segunda falla, la primera no puede
    // quedar suelta.
    return _db.transaction(() async {
      final personaId = await _personas.guardar(cliente.datosPersona);
      final id = await _db
          .into(_tabla)
          .insert(ClienteMapper.modeloACompanion(cliente, personaId: personaId));
      await _anotar(AccionAuditada.creo, id, _nombreDe(cliente));
      return id;
    });
  }

  @override
  Future<void> actualizar(Cliente cliente) {
    exigir(Permiso.clientesEditar);
    return _db.transaction(() async {
      final personaId = await _personas.guardar(cliente.datosPersona);
      await (_db.update(_tabla)..where((t) => t.id.equals(cliente.id))).write(
        ClienteMapper.modeloACompanion(cliente, personaId: personaId),
      );
      await _anotar(AccionAuditada.modifico, cliente.id, _nombreDe(cliente));
    });
  }

  @override
  Future<void> eliminar(int id) {
    exigir(Permiso.clientesEliminar);
    return _db.transaction(() async {
      // El nombre se lee antes: después el cliente ya no está para decirlo.
      final antes = await obtenerPorId(id);
      final personaId = await _personaIdDe(id);

      await (_db.delete(_tabla)..where((t) => t.id.equals(id))).go();
      if (personaId != null) {
        await _personas.borrarSiQuedoSinRoles(personaId);
      }

      await _anotar(
        AccionAuditada.elimino,
        id,
        antes == null ? 'Cliente #$id' : _nombreDe(antes),
      );
    });
  }

  /// Cómo se lee un cliente en la bitácora.
  static String _nombreDe(Cliente cliente) {
    final completo = [cliente.nombres, cliente.apellidos]
        .where((p) => p != null && p.trim().isNotEmpty)
        .join(' ');
    final documento = cliente.documento;
    return documento == null || documento.isEmpty
        ? completo
        : '$completo ($documento)';
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
    // `crear` y `actualizar` traen su propia compuerta, pero las motos se
    // insertan aquí mismo: sin esto, quien no pueda editar clientes podría
    // cambiarle la moto a uno.
    exigir(Permiso.clientesEditar);

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
        //
        // La marca y el modelo llegan como texto y se traducen contra el
        // catálogo, igual que en `RepositorioMotos`: es la misma resolución en
        // los dos caminos que dan de alta motos, y por eso ninguno puede colar
        // una marca escrita de otra forma (`REGLAS_BD.md` §2).
        final marcaId = await _marcas.asegurarMarca(moto.marca);
        final modeloId = await _marcas.asegurarModelo(
          marcaId: marcaId,
          nombre: moto.modelo,
          cilindraje: moto.cilindraje,
        );
        final companion = MotoMapper.modeloACompanion(
          moto.copyWith(
            clienteId: clienteId,
            marcaId: marcaId,
            modeloId: modeloId,
          ),
        );

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
