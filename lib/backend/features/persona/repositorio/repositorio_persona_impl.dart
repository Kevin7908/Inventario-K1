import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../mapper/persona_mapper.dart';
import '../modelo/persona.dart';
import 'repositorio_persona.dart';

class RepositorioPersonaImpl implements RepositorioPersona {
  RepositorioPersonaImpl(this._db);

  final AppDb _db;

  $TablaPersonaTable get _tabla => _db.tablaPersona;

  @override
  Future<PersonaConRoles?> buscarPorDocumento(String documento) async {
    final normalizado = normalizarDocumento(documento);
    if (normalizado == null) return null;

    final fila = await (_db.select(_tabla)
          ..where((p) => p.documento.equals(normalizado)))
        .getSingleOrNull();
    if (fila == null) return null;

    return PersonaConRoles(
      persona: PersonaMapper.filaAModelo(fila),
      roles: await _rolesDe(fila.id),
    );
  }

  @override
  Future<DatosPersona?> obtenerPorId(int id) async {
    final fila =
        await (_db.select(_tabla)..where((p) => p.id.equals(id)))
            .getSingleOrNull();
    return fila == null ? null : PersonaMapper.filaAModelo(fila);
  }

  @override
  Future<String?> duenoDeTelefono(
    String telefono, {
    int? excluirPersonaId,
  }) async {
    final normalizado = telefono.replaceAll(RegExp(r'\D'), '');
    if (normalizado.isEmpty) return null;

    var consulta = _db.select(_tabla)
      ..where((p) => p.telefono.equals(normalizado));
    if (excluirPersonaId != null) {
      consulta = consulta..where((p) => p.id.isNotValue(excluirPersonaId));
    }

    final fila = await consulta.getSingleOrNull();
    if (fila == null) return null;

    final apellidos = fila.apellidos?.trim() ?? '';
    return apellidos.isEmpty
        ? fila.nombres.trim()
        : '${fila.nombres.trim()} $apellidos';
  }

  @override
  Future<int> guardar(DatosPersona datos) async {
    final companion = PersonaMapper.modeloACompanion(datos);

    final existente = datos.personaId ?? await _idPorDocumento(datos.documento);
    if (existente != null) {
      await (_db.update(_tabla)..where((p) => p.id.equals(existente)))
          .write(companion);
      return existente;
    }

    return _db.into(_tabla).insert(companion);
  }

  @override
  Future<void> borrarSiQuedoSinRoles(int personaId) async {
    if ((await _rolesDe(personaId)).isNotEmpty) return;
    await (_db.delete(_tabla)..where((p) => p.id.equals(personaId))).go();
  }

  Future<int?> _idPorDocumento(String? documento) async {
    final normalizado = normalizarDocumento(documento);
    if (normalizado == null) return null;

    final fila = await (_db.selectOnly(_tabla)
          ..addColumns([_tabla.id])
          ..where(_tabla.documento.equals(normalizado)))
        .getSingleOrNull();
    return fila?.read(_tabla.id);
  }

  /// Los cuatro roles en una sola consulta: cuatro `EXISTS` cuestan menos que
  /// cuatro viajes a la base.
  Future<Set<RolPersona>> _rolesDe(int personaId) async {
    final fila = await _db.customSelect(
      '''
      SELECT
        EXISTS(SELECT 1 FROM clientes    WHERE persona_id = ?1) AS es_cliente,
        EXISTS(SELECT 1 FROM tecnicos    WHERE persona_id = ?1) AS es_tecnico,
        EXISTS(SELECT 1 FROM proveedores WHERE persona_id = ?1) AS es_proveedor,
        EXISTS(SELECT 1 FROM usuarios    WHERE persona_id = ?1) AS es_usuario
      ''',
      variables: [Variable.withInt(personaId)],
      readsFrom: {
        _db.tablaCliente,
        _db.tablaTecnico,
        _db.tablaProveedor,
        _db.tablaUsuario,
      },
    ).getSingle();

    return {
      if (fila.read<int>('es_cliente') == 1) RolPersona.cliente,
      if (fila.read<int>('es_tecnico') == 1) RolPersona.tecnico,
      if (fila.read<int>('es_proveedor') == 1) RolPersona.proveedor,
      if (fila.read<int>('es_usuario') == 1) RolPersona.usuario,
    };
  }
}
