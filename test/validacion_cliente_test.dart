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

late AppDb db;

/// Quien firma lo que escriben estos tests. Ver `sesionDePrueba`.
late SesionActual sesion;
late RepositorioClientesImpl clientes;
late RepositorioMotosImpl motos;

Cliente _cliente({int id = 0, String nombres = 'Nuevo', String? documento}) =>
    Cliente(id: id, nombres: nombres, documento: documento, activo: true);

Moto _moto({
  int id = 0,
  String marca = 'Bajaj',
  String modelo = 'Pulsar',
  String? placa,
  String? vin,
}) =>
    Moto(
      id: id,
      clienteId: 0,
      marca: marca,
      modelo: modelo,
      placa: placa,
      vin: vin,
      activo: true,
      creadoEn: DateTime.now(),
      actualizadoEn: DateTime.now(),
    );

Future<Resultado?> _validar(Cliente cliente, List<Moto> lista) => validarCliente(
      cliente: cliente,
      motos: lista,
      repoClientes: clientes,
      repoMotos: motos,
    );

void main() {
  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
    clientes = RepositorioClientesImpl(db, sesion);
    motos = RepositorioMotosImpl(db, sesion);
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

    test('el chasis ajeno también se rechaza', () async {
      await clientes.guardarConMotos(
        cliente: _cliente(nombres: 'Carlos'),
        motos: [_moto(placa: 'AAA111', vin: '9C2KC1670LR000001')],
      );

      final fallo = await _validar(
        _cliente(nombres: 'Intruso'),
        [_moto(placa: 'BBB222', vin: '9C2KC1670LR000001')],
      );

      expect((fallo! as Fallo).motivo, MotivoFallo.placaRegistrada);
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
}
