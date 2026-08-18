// Paginación, filtrado y conteos del repositorio de técnicos.
//
// Corre contra una base SQLite en memoria: es la única forma de comprobar que
// el WHERE, el COUNT y el LIMIT se resuelven de verdad en SQL y no en Dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/tecnicos/modelo/tecnico.dart';
import 'package:inventario_k1/backend/features/tecnicos/repositorio/repositorio_tecnico.dart';
import 'package:inventario_k1/backend/features/tecnicos/repositorio/repositorio_tecnico_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'soporte/base_en_memoria.dart';

late AppDb db;
late RepositorioTecnicoDrift repo;

Tecnico _tecnico({
  required String nombres,
  String? apellidos,
  String? documento,
  String? telefono,
  bool activo = true,
}) =>
    Tecnico(
      nombres: nombres,
      apellidos: apellidos,
      documento: documento,
      telefono: telefono,
      activo: activo,
      creadoEn: DateTime.now(),
    );

Future<List<String>> _nombres(FiltroTecnicos filtro) async {
  final pagina =
      await repo.observarPagina(filtro: filtro, pagina: 0, tamano: 50).first;
  return pagina.items.map((t) => t.nombres).toList();
}

void main() {
  setUp(() async {
    db = baseEnMemoria();
    repo = RepositorioTecnicoDrift(db);
  });

  tearDown(() async => db.close());

  test('la página trae solo su tramo pero informa el total real', () async {
    for (var i = 1; i <= 7; i++) {
      await repo.crear(_tecnico(nombres: 'Tecnico 0$i'));
    }

    final primera = await repo
        .observarPagina(filtro: const FiltroTecnicos(), pagina: 0, tamano: 3)
        .first;

    expect(primera.items.length, 3);
    expect(primera.total, 7, reason: 'el total ignora el LIMIT');
    expect(primera.items.first.nombres, 'Tecnico 01', reason: 'ordena por nombre');

    final ultima = await repo
        .observarPagina(filtro: const FiltroTecnicos(), pagina: 2, tamano: 3)
        .first;

    expect(ultima.items.length, 1, reason: 'la última página va incompleta');
    expect(ultima.items.single.nombres, 'Tecnico 07');
    expect(ultima.total, 7);
  });

  test('la búsqueda filtra en SQL por nombres, apellidos, cédula y teléfono',
      () async {
    await repo.crear(_tecnico(
      nombres: 'Andrés',
      apellidos: 'Patiño',
      documento: '1020304050',
      telefono: '3001112233',
    ));
    await repo.crear(_tecnico(
      nombres: 'Camilo',
      apellidos: 'Ruiz',
      documento: '1030405060',
      telefono: '3002223344',
    ));

    expect(await _nombres(const FiltroTecnicos(busqueda: 'andr')), ['Andrés']);
    expect(await _nombres(const FiltroTecnicos(busqueda: 'ruiz')), ['Camilo']);
    expect(
      await _nombres(const FiltroTecnicos(busqueda: '1020304')),
      ['Andrés'],
    );
    expect(
      await _nombres(const FiltroTecnicos(busqueda: '3002223')),
      ['Camilo'],
    );
    expect(await _nombres(const FiltroTecnicos(busqueda: 'nada')), isEmpty);
  });

  test('un campo opcional vacío no excluye al técnico de la búsqueda',
      () async {
    // Sin apellidos, cédula ni teléfono: en SQL esos LIKE devuelven NULL, no
    // false. Si el OR se tragara el NULL, este técnico sería imposible de
    // encontrar por nombre.
    await repo.crear(_tecnico(nombres: 'Sara Mejía'));

    expect(await _nombres(const FiltroTecnicos(busqueda: 'sara')), ['Sara Mejía']);
  });

  test('el filtro de estado separa activos de inactivos', () async {
    await repo.crear(_tecnico(nombres: 'Vigente'));
    await repo.crear(_tecnico(nombres: 'Retirado', activo: false));

    expect(await _nombres(const FiltroTecnicos()), hasLength(2));
    expect(await _nombres(const FiltroTecnicos(activo: true)), ['Vigente']);
    expect(
      await _nombres(const FiltroTecnicos(activo: false)),
      ['Retirado'],
    );
  });

  test('el total respeta el filtro, no solo la página', () async {
    for (var i = 1; i <= 5; i++) {
      await repo.crear(_tecnico(nombres: 'Activo $i'));
    }
    await repo.crear(_tecnico(nombres: 'Inactivo', activo: false));

    final pagina = await repo
        .observarPagina(
          filtro: const FiltroTecnicos(activo: true),
          pagina: 0,
          tamano: 2,
        )
        .first;

    expect(pagina.items.length, 2);
    expect(pagina.total, 5, reason: 'cuenta los activos, no los seis');
  });

  test('el resumen cuenta el total y los activos', () async {
    await repo.crear(_tecnico(nombres: 'Uno'));
    await repo.crear(_tecnico(nombres: 'Dos'));
    await repo.crear(_tecnico(nombres: 'Tres', activo: false));

    final resumen = await repo.observarResumen().first;

    expect(resumen.total, 3);
    expect(resumen.activos, 2);
  });

  test('la cédula duplicada se detecta y se puede excluir al propio registro',
      () async {
    final creado = await repo.crear(_tecnico(nombres: 'Uno', documento: '111'));

    expect(await repo.existeDocumento('111'), isTrue);
    expect(await repo.existeDocumento('111', excluirId: creado.id), isFalse);
    expect(await repo.existeDocumento('222'), isFalse);
  });
}
