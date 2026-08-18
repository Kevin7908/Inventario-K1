import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/clientes/modelo/cliente.dart';
import 'package:inventario_k1/backend/features/clientes/repositorio/repositorio_cliente_impl.dart';
import 'package:inventario_k1/backend/features/persona/repositorio/repositorio_persona.dart';
import 'package:inventario_k1/backend/features/persona/repositorio/repositorio_persona_impl.dart';
import 'package:inventario_k1/backend/features/tecnicos/modelo/tecnico.dart';
import 'package:inventario_k1/backend/features/tecnicos/repositorio/repositorio_tecnico_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import 'soporte/base_en_memoria.dart';

late AppDb db;
late RepositorioPersonaImpl personas;
late RepositorioClientesImpl clientes;
late RepositorioTecnicoDrift tecnicos;

Cliente _cliente({
  String nombres = 'Juan',
  String? apellidos,
  String? documento,
  String? telefono,
}) =>
    Cliente(
      id: 0,
      nombres: nombres,
      apellidos: apellidos,
      documento: documento,
      telefono: telefono,
      activo: true,
    );

Tecnico _tecnico({
  String nombres = 'Juan',
  String? apellidos,
  String? documento,
  String? telefono,
}) =>
    Tecnico(
      nombres: nombres,
      apellidos: apellidos,
      documento: documento,
      telefono: telefono,
      activo: true,
      creadoEn: DateTime.now(),
    );

Future<int> _filasEnPersonas() async {
  final fila = await db
      .customSelect('SELECT COUNT(*) AS n FROM personas')
      .getSingle();
  return fila.read<int>('n');
}

void main() {
  setUp(() {
    db = baseEnMemoria();
    personas = RepositorioPersonaImpl(db);
    clientes = RepositorioClientesImpl(db);
    tecnicos = RepositorioTecnicoDrift(db);
  });

  tearDown(() => db.close());

  group('reutilización de la persona', () {
    test('quien ya es técnico no se duplica al darlo de alta como cliente',
        () async {
      await tecnicos.crear(
        _tecnico(nombres: 'Juan', apellidos: 'Pérez', documento: '1098765432'),
      );
      final clienteId = await clientes.crear(
        _cliente(nombres: 'Juan', apellidos: 'Pérez', documento: '1098765432'),
      );

      expect(await _filasEnPersonas(), 1);

      final tecnico = (await tecnicos.observarTodos().first).single;
      final cliente = (await clientes.obtenerPorId(clienteId))!;
      expect(cliente.personaId, tecnico.personaId);
    });

    test('el teléfono nuevo llega a los dos roles, porque es una sola fila',
        () async {
      await tecnicos.crear(_tecnico(documento: '111', telefono: '3001111111'));
      await clientes.crear(_cliente(documento: '111', telefono: '3002222222'));

      final tecnico = (await tecnicos.observarTodos().first).single;
      expect(tecnico.telefono, '3002222222');
    });

    test('sin documento no hay forma de saber que son la misma persona',
        () async {
      await tecnicos.crear(_tecnico(nombres: 'Anónimo'));
      await clientes.crear(_cliente(nombres: 'Anónimo'));

      expect(await _filasEnPersonas(), 2);
    });

    test('el documento se normaliza antes de comparar', () async {
      await tecnicos.crear(_tecnico(documento: '1.098.765-432'));
      await clientes.crear(_cliente(documento: '1098765432'));

      expect(await _filasEnPersonas(), 1);
    });
  });

  group('buscarPorDocumento', () {
    test('devuelve los roles que la persona tiene hoy', () async {
      await tecnicos.crear(_tecnico(documento: '111'));

      final encontrada = await personas.buscarPorDocumento('111');

      expect(encontrada, isNotNull);
      expect(encontrada!.roles, {RolPersona.tecnico});
      expect(encontrada.tieneRol(RolPersona.cliente), isFalse);
      expect(encontrada.rolesEnTexto, 'Técnico');
    });

    test('acumula los roles cuando son varios', () async {
      await tecnicos.crear(_tecnico(documento: '111'));
      await clientes.crear(_cliente(documento: '111'));

      final encontrada = await personas.buscarPorDocumento('111');

      expect(encontrada!.roles, {RolPersona.cliente, RolPersona.tecnico});
    });

    test('devuelve null si nadie tiene ese documento', () async {
      expect(await personas.buscarPorDocumento('999'), isNull);
    });
  });

  group('borrado', () {
    test('borrar el cliente deja la persona si sigue siendo técnico', () async {
      await tecnicos.crear(_tecnico(documento: '111'));
      final clienteId = await clientes.crear(_cliente(documento: '111'));

      await clientes.eliminar(clienteId);

      expect(await _filasEnPersonas(), 1);
      expect(await personas.buscarPorDocumento('111'), isNotNull);
    });

    test('borrar el único rol se lleva también la persona', () async {
      final clienteId = await clientes.crear(_cliente(documento: '111'));

      await clientes.eliminar(clienteId);

      expect(await _filasEnPersonas(), 0);
    });
  });

  group('el esquema es el que manda', () {
    test('las FK están activas: no se puede borrar una persona con rol',
        () async {
      await clientes.crear(_cliente(documento: '111'));

      expect(
        () => db.customStatement('DELETE FROM personas WHERE documento = ?',
            ['111']),
        throwsA(isA<Exception>()),
      );
    });

    test('el documento es único aunque nadie lo valide en Dart', () async {
      await db.into(db.tablaPersona).insert(
            TablaPersonaCompanion.insert(
              nombres: 'Uno',
              documento: const Value('111'),
            ),
          );

      expect(
        () => db.into(db.tablaPersona).insert(
              TablaPersonaCompanion.insert(
                nombres: 'Dos',
                documento: const Value('111'),
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('el CHECK rechaza un tipo de documento inventado', () async {
      expect(
        () => db.into(db.tablaPersona).insert(
              TablaPersonaCompanion.insert(
                nombres: 'Uno',
                tipoDocumento: const Value('XX'),
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('el CHECK rechaza una persona sin nombre', () async {
      expect(
        () => db.into(db.tablaPersona).insert(
              TablaPersonaCompanion.insert(nombres: '   '),
            ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
