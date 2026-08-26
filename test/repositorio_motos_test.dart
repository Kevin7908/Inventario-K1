// Paginación, filtros y resumen del repositorio de motos.
//
// Corre contra una base SQLite en memoria: es la única forma de comprobar que
// el WHERE, el COUNT y el LIMIT se resuelven de verdad en SQL —incluido el
// JOIN con clientes, del que depende buscar una moto por el nombre del dueño—
// y no en Dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/clientes/modelo/cliente.dart';
import 'package:inventario_k1/backend/features/clientes/repositorio/repositorio_cliente_impl.dart';
import 'package:inventario_k1/backend/features/motos/modelo/moto.dart';
import 'package:inventario_k1/backend/features/motos/repositorio/repositorio_moto_impl.dart';
import 'package:inventario_k1/backend/features/motos/repositorio/repositorio_motos.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'soporte/base_en_memoria.dart';
import 'soporte/sesion_de_prueba.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';

late AppDb db;

/// Quien firma lo que escriben estos tests. Ver `sesionDePrueba`.
late SesionActual sesion;
late RepositorioMotosImpl repo;
late RepositorioClientesImpl clientes;

Moto _moto({
  required String marca,
  required String modelo,
  required int clienteId,
  String? placa,
  String? color,
  bool activo = true,
}) =>
    Moto(
      id: 0,
      clienteId: clienteId,
      marca: marca,
      modelo: modelo,
      placa: placa,
      color: color,
      activo: activo,
      creadoEn: DateTime.now(),
      actualizadoEn: DateTime.now(),
    );

Future<int> _cliente(String nombres, {String? apellidos}) => clientes.crear(
      Cliente(id: 0, nombres: nombres, apellidos: apellidos, activo: true),
    );

/// Etiqueta "marca modelo" de cada moto de la página, en orden.
Future<List<String>> _nombres(FiltroMotos filtro) async {
  final pagina =
      await repo.observarPagina(filtro: filtro, pagina: 0, tamano: 50).first;
  return pagina.items.map((m) => '${m.marca} ${m.modelo}').toList();
}

void main() {
  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
    repo = RepositorioMotosImpl(db, sesion);
    clientes = RepositorioClientesImpl(db, sesion);
  });

  tearDown(() async => db.close());

  group('paginación', () {
    test('la página trae solo su tramo pero informa el total real', () async {
      final dueno = await _cliente('Carlos');
      for (var i = 1; i <= 7; i++) {
        await repo.crear(
          _moto(marca: 'Marca 0$i', modelo: 'M', clienteId: dueno),
        );
      }

      final primera = await repo
          .observarPagina(filtro: const FiltroMotos(), pagina: 0, tamano: 3)
          .first;

      expect(primera.items, hasLength(3));
      expect(primera.total, 7, reason: 'el LIMIT no debe afectar al COUNT');

      final ultima = await repo
          .observarPagina(filtro: const FiltroMotos(), pagina: 2, tamano: 3)
          .first;

      expect(ultima.items.single.marca, 'Marca 07');
      expect(ultima.total, 7);
    });

    test('el total respeta el filtro, no solo la página', () async {
      final dueno = await _cliente('Carlos');
      for (var i = 1; i <= 5; i++) {
        await repo.crear(
          _moto(marca: 'Activa 0$i', modelo: 'M', clienteId: dueno),
        );
      }
      await repo.crear(
        _moto(marca: 'Baja', modelo: 'M', clienteId: dueno, activo: false),
      );

      final pagina = await repo
          .observarPagina(
            filtro: const FiltroMotos(activo: true),
            pagina: 0,
            tamano: 2,
          )
          .first;

      expect(pagina.items, hasLength(2));
      expect(pagina.total, 5, reason: 'cuenta las activas, no las seis');
    });

    test('recorrer las páginas no repite ni se salta motos empatadas',
        () async {
      // Cuatro motos con la misma marca y el mismo modelo.
      //
      // OJO: este test **no** prueba el desempate por `id` de `_orden`. Se
      // comprobó quitándolo y sigue pasando, porque con un ORDER BY empatado
      // SQLite recorre el índice en orden de rowid y acaba siendo estable de
      // todos modos. El desempate se deja porque ese orden no está garantizado
      // por el motor, pero aquí no hay forma de reproducir el fallo: lo que
      // este test sí fija es que paginar devuelve las cuatro, una vez cada una.
      final dueno = await _cliente('Carlos');
      for (var i = 0; i < 4; i++) {
        await repo.crear(
          _moto(marca: 'Bajaj', modelo: 'Boxer', clienteId: dueno),
        );
      }

      final vistas = <int>[];
      for (var p = 0; p < 2; p++) {
        final pagina = await repo
            .observarPagina(filtro: const FiltroMotos(), pagina: p, tamano: 2)
            .first;
        vistas.addAll(pagina.items.map((m) => m.id));
      }

      expect(vistas, hasLength(4));
      expect(vistas.toSet(), hasLength(4), reason: 'ninguna moto se repite');
    });
  });

  group('filtros', () {
    test('la búsqueda filtra en SQL por marca, modelo, placa y color',
        () async {
      final dueno = await _cliente('Carlos');
      await repo.crear(_moto(
        marca: 'Bajaj',
        modelo: 'Pulsar NS200',
        clienteId: dueno,
        placa: 'KMN12C',
        color: 'Rojo',
      ));
      await repo.crear(_moto(
        marca: 'Honda',
        modelo: 'CB110',
        clienteId: dueno,
        placa: 'ABC99D',
        color: 'Negro',
      ));

      expect(await _nombres(const FiltroMotos(busqueda: 'bajaj')),
          ['Bajaj Pulsar NS200']);
      expect(await _nombres(const FiltroMotos(busqueda: 'cb11')),
          ['Honda CB110']);
      expect(await _nombres(const FiltroMotos(busqueda: 'kmn12')),
          ['Bajaj Pulsar NS200']);
      expect(await _nombres(const FiltroMotos(busqueda: 'negro')),
          ['Honda CB110']);
      expect(await _nombres(const FiltroMotos(busqueda: 'nada')), isEmpty);
    });

    test('la búsqueda encuentra una moto por el nombre de su dueño', () async {
      // El dato no está en `motos`: sale del JOIN con `clientes`. Si el WHERE
      // solo mirara las columnas de la moto, buscar al dueño no devolvería
      // nada.
      final carlos = await _cliente('Carlos', apellidos: 'Ramírez');
      final diana = await _cliente('Diana', apellidos: 'Cardona');
      await repo.crear(
        _moto(marca: 'Bajaj', modelo: 'Boxer', clienteId: carlos),
      );
      await repo.crear(
        _moto(marca: 'Honda', modelo: 'CB110', clienteId: diana),
      );

      expect(await _nombres(const FiltroMotos(busqueda: 'carlos')),
          ['Bajaj Boxer']);
      expect(await _nombres(const FiltroMotos(busqueda: 'cardona')),
          ['Honda CB110']);
    });

    test('un campo opcional vacío no excluye a la moto de la búsqueda',
        () async {
      // Sin placa ni color: en SQL esos LIKE devuelven NULL, no false.
      // Si el OR se tragara el NULL, esta moto sería imposible de encontrar.
      final dueno = await _cliente('Carlos');
      await repo.crear(
        _moto(marca: 'Suzuki', modelo: 'Gixxer', clienteId: dueno),
      );

      expect(await _nombres(const FiltroMotos(busqueda: 'gixxer')),
          ['Suzuki Gixxer']);
    });

    test('el filtro de activas separa las motos dadas de baja', () async {
      final dueno = await _cliente('Carlos');
      await repo.crear(_moto(marca: 'Bajaj', modelo: 'Boxer', clienteId: dueno));
      await repo.crear(_moto(
        marca: 'Honda',
        modelo: 'CB110',
        clienteId: dueno,
        activo: false,
      ));

      expect(await _nombres(const FiltroMotos()), hasLength(2));
      expect(await _nombres(const FiltroMotos(activo: true)), ['Bajaj Boxer']);
      expect(await _nombres(const FiltroMotos(activo: false)), ['Honda CB110']);
    });
  });

  group('resumen', () {
    test('cuenta el total, las activas y las que no tienen placa', () async {
      final dueno = await _cliente('Carlos');
      await repo.crear(_moto(
        marca: 'Bajaj',
        modelo: 'Boxer',
        clienteId: dueno,
        placa: 'KMN12C',
      ));
      await repo.crear(
        _moto(marca: 'Honda', modelo: 'CB110', clienteId: dueno),
      );
      await repo.crear(_moto(
        marca: 'Yamaha',
        modelo: 'FZ',
        clienteId: dueno,
        activo: false,
      ));

      final resumen = await repo.observarResumen().first;

      expect(resumen.total, 3);
      expect(resumen.activas, 2);
      expect(resumen.sinPlaca, 2);
    });
  });

  group('unicidad de placa', () {
    test('duenoDePlaca no distingue mayúsculas y nombra al dueño actual',
        () async {
      // El índice `unique` de SQLite sí distingue, así que sin la comparación
      // en minúsculas "kmn12c" entraría junto a "KMN12C".
      final carlos = await _cliente('Carlos', apellidos: 'Ramírez');
      await repo.crear(_moto(
        marca: 'Bajaj',
        modelo: 'Boxer',
        clienteId: carlos,
        placa: 'KMN12C',
      ));

      final dueno = await repo.duenoDePlaca('kmn12c');

      expect(dueno, isNotNull);
      expect(dueno!.nombreCliente, 'Carlos Ramírez');
    });

    test('una moto no choca consigo misma al editarse', () async {
      final carlos = await _cliente('Carlos');
      final id = await repo.crear(_moto(
        marca: 'Bajaj',
        modelo: 'Boxer',
        clienteId: carlos,
        placa: 'KMN12C',
      ));

      expect(await repo.duenoDePlaca('KMN12C', excluirMotoId: id), isNull);
    });
  });
}
