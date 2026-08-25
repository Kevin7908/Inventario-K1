// Paginación, filtrado y conteos del repositorio de proveedores.
//
// Corre contra una base SQLite en memoria: es la única forma de comprobar que
// el WHERE, el COUNT y el LIMIT se resuelven de verdad en SQL y no en Dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/proveedores/modelo/proveedor.dart';
import 'package:inventario_k1/backend/features/proveedores/repositorio/repositorio_proveedor_impl.dart';
import 'package:inventario_k1/backend/features/proveedores/repositorio/repositorio_proveedores.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'soporte/base_en_memoria.dart';
import 'soporte/sesion_de_prueba.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';

late AppDb db;

/// Quien firma lo que escriben estos tests. Ver `sesionDePrueba`.
late SesionActual sesion;
late RepositorioProveedoresImpl repo;

Proveedor _proveedor({
  required String nombre,
  String? nit,
  String? ciudad,
  String? contacto,
  bool activo = true,
}) =>
    Proveedor(
      nombre: nombre,
      nitCedula: nit,
      ciudad: ciudad,
      contacto: contacto,
      activo: activo,
      colorHex: '#3B82F6',
      icono: 'local_shipping',
      creadoEn: DateTime.now(),
      actualizadoEn: DateTime.now(),
    );

Future<List<String>> _nombres(FiltroProveedores filtro) async {
  final pagina =
      await repo.observarPagina(filtro: filtro, pagina: 0, tamano: 50).first;
  return pagina.items.map((p) => p.nombre).toList();
}

void main() {
  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
    repo = RepositorioProveedoresImpl(db, sesion);
  });

  tearDown(() async => db.close());

  test('la página trae solo su tramo pero informa el total real', () async {
    for (var i = 1; i <= 7; i++) {
      await repo.crear(_proveedor(nombre: 'Proveedor 0$i'));
    }

    final primera = await repo
        .observarPagina(
          filtro: const FiltroProveedores(),
          pagina: 0,
          tamano: 3,
        )
        .first;

    expect(primera.items.length, 3);
    expect(primera.total, 7, reason: 'el total ignora el LIMIT');
    expect(primera.items.first.nombre, 'Proveedor 01', reason: 'ordena por nombre');

    final ultima = await repo
        .observarPagina(
          filtro: const FiltroProveedores(),
          pagina: 2,
          tamano: 3,
        )
        .first;

    expect(ultima.items.length, 1, reason: 'la última página va incompleta');
    expect(ultima.items.single.nombre, 'Proveedor 07');
    expect(ultima.total, 7);
  });

  test('la búsqueda filtra en SQL por nombre, NIT, ciudad y contacto',
      () async {
    await repo.crear(_proveedor(
      nombre: 'Distrimotos',
      nit: '900123456',
      ciudad: 'Bogotá',
      contacto: 'Carlos Méndez',
    ));
    await repo.crear(_proveedor(
      nombre: 'MotoPartes JR',
      nit: '901222333',
      ciudad: 'Medellín',
      contacto: 'Ana Ruiz',
    ));

    expect(await _nombres(const FiltroProveedores(busqueda: 'distri')),
        ['Distrimotos']);
    expect(await _nombres(const FiltroProveedores(busqueda: '901222')),
        ['MotoPartes JR']);
    expect(await _nombres(const FiltroProveedores(busqueda: 'medell')),
        ['MotoPartes JR']);
    expect(await _nombres(const FiltroProveedores(busqueda: 'méndez')),
        ['Distrimotos']);
    expect(await _nombres(const FiltroProveedores(busqueda: 'nada')), isEmpty);
  });

  test('un campo opcional vacío no excluye al proveedor de la búsqueda',
      () async {
    // Sin NIT ni ciudad: en SQL esos LIKE devuelven NULL, no false. Si el OR
    // se tragara el NULL, este proveedor sería imposible de encontrar.
    await repo.crear(_proveedor(nombre: 'Importadora Andina'));

    expect(await _nombres(const FiltroProveedores(busqueda: 'andina')),
        ['Importadora Andina']);
  });

  test('el filtro de estado separa activos de inactivos', () async {
    await repo.crear(_proveedor(nombre: 'Vigente'));
    await repo.crear(_proveedor(nombre: 'Dado de baja', activo: false));

    expect(await _nombres(const FiltroProveedores()), hasLength(2));
    expect(await _nombres(const FiltroProveedores(activo: true)), ['Vigente']);
    expect(
      await _nombres(const FiltroProveedores(activo: false)),
      ['Dado de baja'],
    );
  });

  test('el total respeta el filtro, no solo la página', () async {
    for (var i = 1; i <= 5; i++) {
      await repo.crear(_proveedor(nombre: 'Activo $i'));
    }
    await repo.crear(_proveedor(nombre: 'Inactivo', activo: false));

    final pagina = await repo
        .observarPagina(
          filtro: const FiltroProveedores(activo: true),
          pagina: 0,
          tamano: 2,
        )
        .first;

    expect(pagina.items.length, 2);
    expect(pagina.total, 5, reason: 'cuenta los activos, no los seis');
  });

  test('el resumen cuenta el total y los activos', () async {
    await repo.crear(_proveedor(nombre: 'Uno'));
    await repo.crear(_proveedor(nombre: 'Dos'));
    await repo.crear(_proveedor(nombre: 'Tres', activo: false));

    final resumen = await repo.observarResumen().first;

    expect(resumen.total, 3);
    expect(resumen.activos, 2);
  });
}
