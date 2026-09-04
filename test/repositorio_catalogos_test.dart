import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/configuracion/modelo/clave_configuracion.dart';
import 'package:inventario_k1/backend/features/configuracion/repositorio/repositorio_configuracion_impl.dart';
import 'package:inventario_k1/backend/features/motos/repositorio/repositorio_moto_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/datos_taller.dart';
import 'soporte/sesion_de_prueba.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';

late AppDb db;

/// Quien firma lo que escriben estos tests. Ver `sesionDePrueba`.
late SesionActual sesion;
late RepositorioMotosImpl motos;
late RepositorioConfiguracionImpl configuracion;
late DatosTaller taller;

void main() {
  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
    motos = RepositorioMotosImpl(db, sesion);
    configuracion = RepositorioConfiguracionImpl(db, sesion);
    taller = await sembrarTaller(db);
  });

  tearDown(() => db.close());

  group('motos', () {
    test('el activo se lee de vuelta como bool, no como 0/1', () async {
      // La columna era `IntColumn` 0/1 y el mapper hacía `fila.activo == 1`.
      // Al pasarla a `BoolColumn` esa comparación quedó siendo `bool == int`:
      // compila, no la ve el analizador, y devuelve siempre `false`.
      final moto = (await motos.obtenerPorCliente(taller.clienteId)).single;
      expect(moto.activo, isTrue);

      await db.customStatement(
        'UPDATE motos SET activo = 0 WHERE id = ${taller.motoId}',
      );
      final dadaDeBaja =
          (await motos.obtenerPorCliente(taller.clienteId)).single;
      expect(dadaDeBaja.activo, isFalse);
    });

    test('la placa no se repite', () async {
      expect(
        () => db.into(db.tablaMoto).insert(
              TablaMotoCompanion.insert(
                clienteId: taller.clienteId,
                marcaId: taller.marcaId,
                placa: const Value('KMN12C'),
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('un año imposible se rechaza', () async {
      expect(
        () => db.into(db.tablaMoto).insert(
              TablaMotoCompanion.insert(
                clienteId: taller.clienteId,
                marcaId: taller.marcaId,
                anio: const Value(12),
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('un cilindraje de cero se rechaza', () async {
      // El cilindraje se mudó a `modelos_moto`: es del modelo, no del
      // ejemplar. El CHECK se mudó con él.
      expect(
        () => db.into(db.tablaModeloMoto).insert(
              TablaModeloMotoCompanion.insert(
                marcaId: taller.marcaId,
                nombre: 'Otro',
                cilindraje: const Value(0),
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('una moto no puede apuntar a una marca que no existe', () async {
      // La FK es la que lo impide, y solo con `PRAGMA foreign_keys = ON`.
      expect(
        () => db.into(db.tablaMoto).insert(
              TablaMotoCompanion.insert(
                clienteId: taller.clienteId,
                marcaId: 9999,
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('las FK impiden borrar a un cliente con motos', () async {
      // Comprueba que la FK está activa y rechaza el borrado. **No**
      // distingue `RESTRICT` de `NO ACTION`: con restricciones inmediatas
      // —las únicas que usa este proyecto— las dos fallan igual. Escribir
      // `restrict` explícito es declarar la intención, no cambiar la
      // conducta; lo que sí se distingue de verdad es `cascade` y `setNull`,
      // y esos tienen sus propios tests.
      expect(
        () => db.customStatement(
            'DELETE FROM clientes WHERE id = ${taller.clienteId}'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('catálogos', () {
    test('categorías y unidades se dan de baja, no se borran', () async {
      // El `activo` no existía: la única forma de retirar una categoría era
      // borrarla, y eso dejaba productos sin clasificar.
      final categoriaId = await db.into(db.tablaCategoria).insert(
            TablaCategoriaCompanion.insert(nombre: 'Frenos'),
          );
      final unidadId = await db.into(db.tablaUnidadesMedida).insert(
            TablaUnidadesMedidaCompanion.insert(
              nombre: 'Litro',
              abreviatura: 'lt',
            ),
          );

      await db.customStatement(
          'UPDATE categorias SET activo = 0 WHERE id = $categoriaId');
      await db.customStatement(
          'UPDATE unidades_medida SET activo = 0 WHERE id = $unidadId');

      final categoria = await (db.select(db.tablaCategoria)
            ..where((c) => c.id.equals(categoriaId)))
          .getSingle();
      expect(categoria.activo, isFalse);
    });

    test('el nombre de la categoría no se repite', () async {
      await db
          .into(db.tablaCategoria)
          .insert(TablaCategoriaCompanion.insert(nombre: 'Frenos'));

      expect(
        () => db
            .into(db.tablaCategoria)
            .insert(TablaCategoriaCompanion.insert(nombre: 'Frenos')),
        throwsA(isA<Exception>()),
      );
    });

    test('un nombre en blanco se rechaza', () async {
      expect(
        () => db
            .into(db.tablaCategoria)
            .insert(TablaCategoriaCompanion.insert(nombre: '   ')),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('configuración', () {
    test('una clave sin configurar devuelve su valor por defecto', () async {
      expect(await configuracion.leer(ClaveConfiguracion.formatoImpresion),
          'CARTA');
      expect(await configuracion.leer(ClaveConfiguracion.nit), '');
    });

    test('guardar dos veces la misma clave actualiza, no duplica', () async {
      await configuracion.guardar(ClaveConfiguracion.nit, '900123456');
      await configuracion.guardar(ClaveConfiguracion.nit, '900999999');

      expect(await configuracion.leer(ClaveConfiguracion.nit), '900999999');

      final filas = await db
          .customSelect("SELECT COUNT(*) AS n FROM configuracion "
              "WHERE clave = 'nit'")
          .getSingle();
      expect(filas.read<int>('n'), 1);
    });

    test('el mapa completo trae todas las claves, configuradas o no',
        () async {
      await configuracion.guardar(ClaveConfiguracion.ciudad, 'Medellín');

      final valores = await configuracion.observarTodas().first;

      expect(valores.keys.toSet(), ClaveConfiguracion.values.toSet());
      expect(valores[ClaveConfiguracion.ciudad], 'Medellín');
      expect(valores[ClaveConfiguracion.formatoImpresion], 'CARTA');
    });
  });
}
