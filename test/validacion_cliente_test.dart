// La regla central del módulo: un cliente puede tener varias motos, pero una
// moto que ya tiene dueño no se puede reasignar desde otro cliente.
//
// Corre contra una base en memoria porque la regla no se puede comprobar sin
// consultar de verdad quién es el dueño actual.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/clientes/modelo/cliente.dart';
import 'package:inventario_k1/backend/features/clientes/repositorio/repositorio_cliente_impl.dart';
import 'package:inventario_k1/backend/features/motos/modelo/moto.dart';
import 'package:inventario_k1/backend/features/motos/repositorio/repositorio_moto_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/core/resultado.dart';
import 'package:inventario_k1/frontend/features/clientes/provider/validacion_cliente.dart';
import 'soporte/base_en_memoria.dart';
import 'soporte/sesion_de_prueba.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';
import 'package:inventario_k1/backend/features/persona/repositorio/repositorio_persona_impl.dart';

late AppDb db;

/// Quien firma lo que escriben estos tests. Ver `sesionDePrueba`.
late SesionActual sesion;
late RepositorioClientesImpl clientes;
late RepositorioMotosImpl motos;
late RepositorioPersonaImpl personas;

Cliente _cliente({
  int id = 0,
  String nombres = 'Nuevo',
  String? documento,
  String? telefono,
}) =>
    Cliente(
      id: id,
      nombres: nombres,
      documento: documento,
      telefono: telefono,
      activo: true,
    );

Moto _moto({
  int id = 0,
  String marca = 'Bajaj',
  String modelo = 'Pulsar',
  String? placa,
}) =>
    Moto(
      id: id,
      clienteId: 0,
      marca: marca,
      modelo: modelo,
      placa: placa,
      activo: true,
      creadoEn: DateTime.now(),
      actualizadoEn: DateTime.now(),
    );

Future<Resultado?> _validar(Cliente cliente, List<Moto> lista) => validarCliente(
      cliente: cliente,
      motos: lista,
      repoClientes: clientes,
      repoMotos: motos,
      repoPersonas: personas,
    );

void main() {
  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
    clientes = RepositorioClientesImpl(db, sesion);
    motos = RepositorioMotosImpl(db, sesion);
    personas = RepositorioPersonaImpl(db);
  });

  tearDown(() async => db.close());

  group('motos ajenas', () {
    test('rechaza una moto que ya tiene dueño y dice quién es', () async {
      await clientes.guardarConMotos(
        cliente: _cliente(nombres: 'Carlos'),
        motos: [_moto(placa: 'KMN12C')],
      );

      final fallo = await _validar(
        _cliente(nombres: 'Intruso'),
        [_moto(placa: 'KMN12C')],
      );

      expect(fallo, isA<Fallo>());
      expect((fallo! as Fallo).motivo, MotivoFallo.placaRegistrada);
      expect(
        (fallo as Fallo).mensaje,
        contains('Carlos'),
        reason: 'el mensaje debe nombrar al dueño actual, no solo la placa',
      );
    });

    test('la placa se compara sin distinguir mayúsculas', () async {
      await clientes.guardarConMotos(
        cliente: _cliente(nombres: 'Carlos'),
        motos: [_moto(placa: 'KMN12C')],
      );

      expect(
        await _validar(_cliente(nombres: 'Intruso'), [_moto(placa: 'kmn12c')]),
        isA<Fallo>(),
      );
    });

  });

  group('motos propias', () {
    test('un cliente puede registrar varias motos de una vez', () async {
      expect(
        await _validar(_cliente(nombres: 'Carlos'), [
          _moto(marca: 'Bajaj', modelo: 'Pulsar NS200', placa: 'KMN12C'),
          _moto(marca: 'AKT', modelo: '125', placa: 'LPQ04A'),
          _moto(marca: 'Honda', modelo: 'CB110', placa: 'HRT88D'),
        ]),
        isNull,
      );
    });

    test('editar sin tocar la placa no se rechaza a sí mismo', () async {
      final id = await clientes.guardarConMotos(
        cliente: _cliente(nombres: 'Carlos'),
        motos: [_moto(placa: 'KMN12C')],
      );
      final guardado = (await clientes.obtenerPorId(id))!;
      final propia = (await motos.obtenerPorCliente(id)).single;

      expect(
        await _validar(guardado, [propia]),
        isNull,
        reason: 'la moto debe excluirse de su propia comprobación de unicidad',
      );
    });

    test('varias motos sin placa conviven sin chocar', () async {
      expect(
        await _validar(_cliente(nombres: 'Carlos'), [
          _moto(marca: 'Bajaj', modelo: 'Boxer'),
          _moto(marca: 'Yamaha', modelo: 'YBR'),
        ]),
        isNull,
        reason: 'placa vacía es "sin dato", no un valor que pueda repetirse',
      );
    });

    test('repetir la placa dentro del propio formulario se avisa', () async {
      final fallo = await _validar(_cliente(nombres: 'Carlos'), [
        _moto(marca: 'Bajaj', modelo: 'Pulsar', placa: 'KMN12C'),
        _moto(marca: 'AKT', modelo: '125', placa: 'kmn12c'),
      ]);

      expect((fallo! as Fallo).motivo, MotivoFallo.placaRegistrada);
      expect((fallo as Fallo).mensaje, contains('Repetiste'));
    });

    test('una moto sin marca o sin modelo no pasa', () async {
      expect(
        await _validar(_cliente(), [_moto(marca: '  ', modelo: 'Pulsar')]),
        isA<Fallo>(),
      );
      expect(
        await _validar(_cliente(), [_moto(marca: 'Bajaj', modelo: '')]),
        isA<Fallo>(),
      );
    });
  });

  group('datos del cliente', () {
    test('el nombre vacío o de una letra no pasa', () async {
      expect(await _validar(_cliente(nombres: '  '), []), isA<Fallo>());
      expect(await _validar(_cliente(nombres: 'A'), []), isA<Fallo>());
      expect(await _validar(_cliente(nombres: 'Ana'), []), isNull);
    });

    test('la cédula duplicada se rechaza, salvo la del propio cliente',
        () async {
      final id = await clientes.crear(_cliente(nombres: 'Carlos', documento: '111'));

      final fallo = await _validar(_cliente(nombres: 'Otro', documento: '111'), []);
      expect((fallo! as Fallo).motivo, MotivoFallo.documentoDuplicado);

      expect(
        await _validar(_cliente(id: id, nombres: 'Carlos', documento: '111'), []),
        isNull,
      );
    });
  });

  group('el teléfono no se repite', () {
    // Vive en `personas`, que comparten los cuatro roles: el número que se
    // teclea para un cliente puede ser el del proveedor de al lado. La
    // comprobación es de cortesía —para dar un mensaje que se entienda—; la
    // que impide de verdad es el `UNIQUE` de la tabla.

    test('el de otro cliente se rechaza y dice de quién es', () async {
      await clientes.guardarConMotos(
        cliente: _cliente(nombres: 'Carlos', telefono: '3001234567'),
        motos: const [],
      );

      final fallo = await _validar(
        _cliente(nombres: 'Intruso', telefono: '3001234567'),
        const [],
      );

      expect((fallo! as Fallo).motivo, MotivoFallo.telefonoDuplicado);
      expect((fallo as Fallo).mensaje, contains('Carlos'));
    });

    test('un cliente no choca consigo mismo al editarse', () async {
      await clientes.guardarConMotos(
        cliente: _cliente(nombres: 'Carlos', telefono: '3001234567'),
        motos: const [],
      );
      final guardado = (await clientes.obtenerTodos()).single;

      expect(
        await _validar(
          _cliente(
            id: guardado.id,
            nombres: 'Carlos',
            telefono: '3001234567',
          ).copyWith(personaId: guardado.personaId),
          const [],
        ),
        isNull,
      );
    });

    test('sin teléfono no se compara nada', () async {
      await clientes.guardarConMotos(
        cliente: _cliente(nombres: 'Carlos'),
        motos: const [],
      );

      expect(await _validar(_cliente(nombres: 'Otro'), const []), isNull);
    });
  });
}
