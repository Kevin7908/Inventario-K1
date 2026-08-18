// Paginación, filtros, saldos y guardado con motos del repositorio de clientes.
//
// Corre contra una base SQLite en memoria: es la única forma de comprobar que
// el WHERE, el COUNT, el GROUP BY y el LIMIT se resuelven de verdad en SQL y
// no en Dart.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/clientes/modelo/cliente.dart';
import 'package:inventario_k1/backend/features/clientes/repositorio/repositorio_cliente.dart';
import 'package:inventario_k1/backend/features/clientes/repositorio/repositorio_cliente_impl.dart';
import 'package:inventario_k1/backend/features/motos/modelo/moto.dart';
import 'package:inventario_k1/backend/features/motos/repositorio/repositorio_moto_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'soporte/base_en_memoria.dart';

late AppDb db;
late RepositorioClientesImpl repo;
late RepositorioMotosImpl motos;

Cliente _cliente({
  required String nombres,
  String? apellidos,
  String? documento,
  String? telefono,
  String? email,
  String? ciudad,
  bool activo = true,
}) =>
    Cliente(
      id: 0,
      nombres: nombres,
      apellidos: apellidos,
      documento: documento,
      telefono: telefono,
      email: email,
      ciudad: ciudad,
      activo: activo,
    );

Moto _moto({
  int id = 0,
  int clienteId = 0,
  String marca = 'Bajaj',
  String modelo = 'Pulsar',
  String? placa,
}) =>
    Moto(
      id: id,
      clienteId: clienteId,
      marca: marca,
      modelo: modelo,
      placa: placa,
      activo: true,
      creadoEn: DateTime.now(),
      actualizadoEn: DateTime.now(),
    );

Future<List<String>> _nombres(FiltroClientes filtro) async {
  final pagina =
      await repo.observarPagina(filtro: filtro, pagina: 0, tamano: 50).first;
  return pagina.items.map((c) => c.nombres).toList();
}

/// Inserta una deuda directamente: el módulo de Deudores tiene su propio
/// repositorio, y aquí solo interesa que el saldo se calcule sobre la tabla.
Future<void> _deuda({
  required int clienteId,
  required String numero,
  required int total,
  int pagado = 0,
  String estado = 'ACTIVA',
}) async {
  await db.into(db.tablaDeudor).insert(
        TablaDeudorCompanion.insert(
          numero: numero,
          clienteId: clienteId,
          concepto: 'Prueba',
          montoTotal: total,
          montoPagado: Value(pagado),
          estado: Value(estado),
        ),
      );
}

void main() {
  setUp(() {
    db = baseEnMemoria();
    repo = RepositorioClientesImpl(db);
    motos = RepositorioMotosImpl(db);
  });

  tearDown(() async => db.close());

  group('paginación', () {
    test('la página trae solo su tramo pero informa el total real', () async {
      for (var i = 1; i <= 7; i++) {
        await repo.crear(_cliente(nombres: 'Cliente 0$i'));
      }

      final primera = await repo
          .observarPagina(filtro: const FiltroClientes(), pagina: 0, tamano: 3)
          .first;

      expect(primera.items.length, 3);
      expect(primera.total, 7, reason: 'el total ignora el LIMIT');
      expect(primera.items.first.nombres, 'Cliente 01', reason: 'ordena por nombre');

      final ultima = await repo
          .observarPagina(filtro: const FiltroClientes(), pagina: 2, tamano: 3)
          .first;

      expect(ultima.items.single.nombres, 'Cliente 07');
      expect(ultima.total, 7);
    });

    test('el total respeta el filtro, no solo la página', () async {
      for (var i = 1; i <= 5; i++) {
        await repo.crear(_cliente(nombres: 'Activo $i'));
      }
      await repo.crear(_cliente(nombres: 'Retirado', activo: false));

      final pagina = await repo
          .observarPagina(
            filtro: const FiltroClientes(activo: true),
            pagina: 0,
            tamano: 2,
          )
          .first;

      expect(pagina.items.length, 2);
      expect(pagina.total, 5, reason: 'cuenta los activos, no los seis');
    });
  });

  group('filtros', () {
    test('la búsqueda filtra en SQL por nombre, cédula, teléfono y ciudad',
        () async {
      await repo.crear(_cliente(
        nombres: 'Carlos',
        apellidos: 'Ramírez',
        documento: '1020304050',
        telefono: '3005551234',
        ciudad: 'Medellín',
      ));
      await repo.crear(_cliente(
        nombres: 'María',
        apellidos: 'Gómez',
        documento: '1030405060',
        telefono: '3112228890',
        ciudad: 'Bogotá',
      ));

      expect(await _nombres(const FiltroClientes(busqueda: 'carl')), ['Carlos']);
      expect(await _nombres(const FiltroClientes(busqueda: 'gómez')), ['María']);
      expect(await _nombres(const FiltroClientes(busqueda: '102030')), ['Carlos']);
      expect(await _nombres(const FiltroClientes(busqueda: '311222')), ['María']);
      expect(await _nombres(const FiltroClientes(busqueda: 'bogot')), ['María']);
      expect(await _nombres(const FiltroClientes(busqueda: 'nada')), isEmpty);
    });

    test('un campo opcional vacío no excluye al cliente de la búsqueda',
        () async {
      // Sin apellidos, cédula, teléfono ni ciudad: en SQL esos LIKE devuelven
      // NULL, no false. Si el OR se tragara el NULL, este cliente sería
      // imposible de encontrar por nombre.
      await repo.crear(_cliente(nombres: 'Diana Cardona'));

      expect(
        await _nombres(const FiltroClientes(busqueda: 'diana')),
        ['Diana Cardona'],
      );
    });

    test('el filtro de activos separa a quien ya no viene al taller', () async {
      await repo.crear(_cliente(nombres: 'Persona'));
      await repo.crear(_cliente(nombres: 'Se mudó', activo: false));

      expect(await _nombres(const FiltroClientes()), hasLength(2));
      expect(await _nombres(const FiltroClientes(activo: true)), ['Persona']);
      expect(await _nombres(const FiltroClientes(activo: false)), ['Se mudó']);
    });
  });

  group('resumen y saldos', () {
    test('el resumen cuenta el total y los que deben', () async {
      final carlos = await repo.crear(_cliente(nombres: 'Carlos'));
      await repo.crear(_cliente(nombres: 'Diana'));
      final rayo = await repo.crear(_cliente(nombres: 'El Rayo'));

      await _deuda(clienteId: carlos, numero: 'D-1', total: 80000);
      await _deuda(clienteId: rayo, numero: 'D-2', total: 250000);

      final resumen = await repo.observarResumen().first;

      expect(resumen.total, 3);
      expect(resumen.conSaldo, 2);
    });

    test('el saldo suma lo pendiente de las deudas vivas', () async {
      final carlos = await repo.crear(_cliente(nombres: 'Carlos'));

      await _deuda(clienteId: carlos, numero: 'D-1', total: 100000, pagado: 40000);
      await _deuda(clienteId: carlos, numero: 'D-2', total: 30000);

      final saldos = await repo.observarSaldos().first;

      expect(saldos[carlos]!.pendiente, 90000, reason: '60.000 + 30.000');
      expect(saldos[carlos]!.deudas, 2);
    });

    test('una deuda pagada o incobrable no deja al cliente en rojo', () async {
      final alDia = await repo.crear(_cliente(nombres: 'Al día'));
      final perdonado = await repo.crear(_cliente(nombres: 'Incobrable'));
      // Saldada de hecho, pero todavía marcada ACTIVA: si el filtro mirara
      // solo el estado, este cliente aparecería debiendo $0.
      final saldada = await repo.crear(_cliente(nombres: 'Saldada'));

      await _deuda(
        clienteId: alDia,
        numero: 'D-1',
        total: 50000,
        pagado: 50000,
        estado: 'PAGADA',
      );
      await _deuda(
        clienteId: perdonado,
        numero: 'D-2',
        total: 50000,
        estado: 'INCOBRABLE',
      );
      await _deuda(clienteId: saldada, numero: 'D-3', total: 50000, pagado: 50000);

      final saldos = await repo.observarSaldos().first;

      expect(saldos, isEmpty);
      expect((await repo.observarResumen().first).conSaldo, 0);
    });

    test('una deuda VENCIDA sí cuenta como saldo', () async {
      final moroso = await repo.crear(_cliente(nombres: 'Moroso'));
      await _deuda(
        clienteId: moroso,
        numero: 'D-1',
        total: 67000,
        estado: 'VENCIDA',
      );

      expect((await repo.observarSaldos().first)[moroso]!.pendiente, 67000);
    });
  });

  group('guardado con motos', () {
    test('crea el cliente y sus motos en una sola llamada', () async {
      final id = await repo.guardarConMotos(
        cliente: _cliente(nombres: 'Carlos'),
        motos: [
          _moto(marca: 'Bajaj', modelo: 'Pulsar NS200', placa: 'KMN12C'),
          _moto(marca: 'AKT', modelo: '125', placa: 'LPQ04A'),
        ],
      );

      final guardadas = await motos.obtenerPorCliente(id);

      expect(guardadas, hasLength(2));
      expect(guardadas.every((m) => m.clienteId == id), isTrue);
    });

    test('al editar agrega, actualiza y borra en el mismo guardado', () async {
      final id = await repo.guardarConMotos(
        cliente: _cliente(nombres: 'Carlos'),
        motos: [
          _moto(marca: 'Bajaj', modelo: 'Pulsar', placa: 'AAA111'),
          _moto(marca: 'Yamaha', modelo: 'YBR', placa: 'BBB222'),
        ],
      );

      final previas = await motos.obtenerPorCliente(id);
      final aConservar = previas.firstWhere((m) => m.placa == 'AAA111');

      await repo.guardarConMotos(
        cliente: (await repo.obtenerPorId(id))!,
        motos: [
          // La Yamaha no viene: debe borrarse.
          aConservar.copyWith(modelo: 'Pulsar NS200'),
          _moto(marca: 'Suzuki', modelo: 'GN125', placa: 'CCC333'),
        ],
      );

      final finales = await motos.obtenerPorCliente(id);

      expect(finales.map((m) => m.placa), unorderedEquals(['AAA111', 'CCC333']));
      expect(
        finales.firstWhere((m) => m.placa == 'AAA111').modelo,
        'Pulsar NS200',
        reason: 'la moto conservada se actualizó, no se duplicó',
      );
    });

    test('si una moto choca, no queda el cliente a medio crear', () async {
      final otro = await repo.guardarConMotos(
        cliente: _cliente(nombres: 'Dueño original'),
        motos: [_moto(placa: 'KMN12C')],
      );
      expect(otro, isPositive);

      // La segunda moto repite una placa ya registrada: la restricción UNIQUE
      // revienta el INSERT y la transacción debe deshacer también el cliente.
      await expectLater(
        repo.guardarConMotos(
          cliente: _cliente(nombres: 'Intruso'),
          motos: [_moto(placa: 'ZZZ999'), _moto(placa: 'KMN12C')],
        ),
        throwsA(anything),
      );

      expect(
        await _nombres(const FiltroClientes(busqueda: 'intruso')),
        isEmpty,
        reason: 'la transacción se deshizo entera',
      );
    });
  });

  group('unicidad', () {
    test('la cédula duplicada se detecta y se excluye al propio registro',
        () async {
      final id = await repo.crear(_cliente(nombres: 'Uno', documento: '111'));

      expect(await repo.existeDocumento('111'), isTrue);
      expect(await repo.existeDocumento('111', excluirId: id), isFalse);
      expect(await repo.existeDocumento('222'), isFalse);
    });

    test('el documento se normaliza: «1.098.765» y «1098765» son el mismo',
        () async {
      await repo.crear(_cliente(nombres: 'Uno', documento: '1.098.765'));

      expect(await repo.existeDocumento('1098765'), isTrue);
      expect(await repo.existeDocumento('1.098-765'), isTrue);
    });

    test('duenoDePlaca dice quién tiene la moto, ignorando mayúsculas',
        () async {
      final id = await repo.guardarConMotos(
        cliente: _cliente(nombres: 'Carlos', apellidos: 'Ramírez'),
        motos: [_moto(placa: 'KMN12C')],
      );
      final propia = (await motos.obtenerPorCliente(id)).single;

      final dueno = await motos.duenoDePlaca('kmn12c');
      expect(dueno, isNotNull);
      expect(dueno!.nombreCliente, 'Carlos Ramírez');

      expect(
        await motos.duenoDePlaca('KMN12C', excluirMotoId: propia.id),
        isNull,
        reason: 'editar la moto sin tocar la placa no puede rechazarse a sí misma',
      );
      expect(await motos.duenoDePlaca('LIBRE1'), isNull);
    });
  });

  group('resumen de motos por cliente', () {
    test('cuenta las motos y elige una principal determinista', () async {
      final carlos = await repo.guardarConMotos(
        cliente: _cliente(nombres: 'Carlos'),
        motos: [
          _moto(marca: 'Bajaj', modelo: 'Pulsar NS200', placa: 'KMN12C'),
          _moto(marca: 'AKT', modelo: '125', placa: 'LPQ04A'),
        ],
      );
      final sinMotos = await repo.crear(_cliente(nombres: 'Sin motos'));

      final resumen = await motos.observarResumenPorCliente().first;

      expect(resumen[carlos]!.cantidad, 2);
      expect(
        resumen[carlos]!.principal,
        'AKT 125 · LPQ04A',
        reason: 'la primera en orden alfabético de marca',
      );
      expect(resumen.containsKey(sinMotos), isFalse);
    });

    test('una moto sin placa no rompe la etiqueta', () async {
      final id = await repo.guardarConMotos(
        cliente: _cliente(nombres: 'Andrés'),
        motos: [_moto(marca: 'Honda', modelo: 'CB110')],
      );

      final resumen = await motos.observarResumenPorCliente().first;

      expect(resumen[id]!.principal, 'Honda CB110');
    });
  });
}
