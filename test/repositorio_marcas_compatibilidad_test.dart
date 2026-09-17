import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/motos/repositorio/repositorio_marcas_moto_impl.dart';
import 'package:inventario_k1/backend/features/productos/repositorio/repositorio_compatibilidades_impl.dart';
import 'package:inventario_k1/backend/features/productos/repositorio/repositorio_producto.dart';
import 'package:inventario_k1/backend/features/productos/repositorio/repositorio_producto_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/permiso.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';
import 'package:inventario_k1/core/resultado.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/sesion_de_prueba.dart';

/// El catálogo de marcas y modelos, y a qué motos le sirve cada repuesto.
void main() {
  late AppDb db;
  late SesionActual sesion;
  late RepositorioMarcasMotoImpl marcas;
  late RepositorioCompatibilidadesImpl compat;
  late RepositorioProductosImpl productos;

  Future<int> producto(String sku, {String? codigoBarras}) => db
      .into(db.tablaProducto)
      .insert(TablaProductoCompanion.insert(
        sku: sku,
        nombre: 'Repuesto $sku',
        codigoBarras: Value(codigoBarras),
      ));

  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
    marcas = RepositorioMarcasMotoImpl(db, sesion);
    compat = RepositorioCompatibilidadesImpl(db, sesion);
    productos = RepositorioProductosImpl(db, sesion);
  });

  tearDown(() => db.close());

  group('catálogo de marcas', () {
    test('la marca entra normalizada, no como se teclee', () async {
      // Es la razón de ser de la tabla: con texto libre, «yamaha», «Yamaha» y
      // « YAMAHA » eran tres marcas distintas y ningún informe las cruzaba.
      await marcas.crearMarca('  yamaha  ');

      expect((await marcas.obtenerMarcas()).single.nombre, 'Yamaha');
    });

    test('la misma marca no entra dos veces aunque cambie la caja', () async {
      expect(await marcas.crearMarca('Bajaj'), isA<Exito>());

      final repetida = await marcas.crearMarca('BAJAJ');

      expect((repetida as Fallo).motivo, MotivoFallo.nombreDuplicado);
      expect(await marcas.obtenerMarcas(), hasLength(1));
    });

    test('el mismo modelo sí puede existir en dos marcas', () async {
      // El `UNIQUE` es compuesto `(marca_id, nombre)` y no solo el nombre:
      // «Discover» existe en Bajaj y podría existir en otra sin estorbarse.
      await marcas.crearMarca('Bajaj');
      await marcas.crearMarca('Honda');
      final lista = await marcas.obtenerMarcas();
      final bajaj = lista.firstWhere((m) => m.nombre == 'Bajaj');
      final honda = lista.firstWhere((m) => m.nombre == 'Honda');

      expect(
        await marcas.crearModelo(marcaId: bajaj.id, nombre: 'Discover'),
        isA<Exito>(),
      );
      expect(
        await marcas.crearModelo(marcaId: honda.id, nombre: 'Discover'),
        isA<Exito>(),
      );
      expect(
        (await marcas.crearModelo(marcaId: bajaj.id, nombre: 'discover'))
            as Fallo,
        isA<Fallo>(),
      );
    });

    test('el conteo de modelos sale del COUNT, no de una lista en memoria',
        () async {
      await marcas.crearMarca('Yamaha');
      final yamaha = (await marcas.obtenerMarcas()).single;
      await marcas.crearModelo(marcaId: yamaha.id, nombre: 'FZ 2.0');
      await marcas.crearModelo(marcaId: yamaha.id, nombre: 'MT 03');

      expect((await marcas.obtenerMarcas()).single.modelos, 2);
    });

    test('una marca con motos no se puede borrar: se da de baja', () async {
      // `restrict` en la FK. Borrarla se llevaría por delante el historial de
      // taller de esa moto (§1.4).
      await marcas.crearMarca('Suzuki');
      final suzuki = (await marcas.obtenerMarcas()).single;
      final personaId = await db.into(db.tablaPersona).insert(
            TablaPersonaCompanion.insert(nombres: 'Cliente'),
          );
      final clienteId = await db
          .into(db.tablaCliente)
          .insert(TablaClienteCompanion.insert(personaId: personaId));
      await db.into(db.tablaMoto).insert(
            TablaMotoCompanion.insert(
              clienteId: clienteId,
              marcaId: suzuki.id,
            ),
          );

      expect(
        () => db.delete(db.tablaMarcaMoto).go(),
        throwsA(isA<Exception>()),
      );
      expect(
        await marcas.cambiarEstadoMarca(suzuki.id, activa: false),
        isA<Exito>(),
      );
    });

    test('asegurarMarca reutiliza la que ya está en vez de duplicarla',
        () async {
      await marcas.crearMarca('Honda');
      final id = (await marcas.obtenerMarcas()).single.id;

      expect(await marcas.asegurarMarca('  honda '), id);
      expect(await marcas.obtenerMarcas(), hasLength(1));
    });

    test('asegurarModelo completa el cilindraje que faltaba, pero no lo pisa',
        () async {
      final marcaId = await marcas.asegurarMarca('Bajaj');
      final id = await marcas.asegurarModelo(
        marcaId: marcaId,
        nombre: 'Boxer CT100',
      );

      await marcas.asegurarModelo(
        marcaId: marcaId,
        nombre: 'Boxer CT100',
        cilindraje: 100,
      );
      expect((await marcas.obtenerModelos()).single.cilindraje, 100);

      // Ya está: lo que teclee quien registra una moto suelta no manda sobre
      // el catálogo.
      await marcas.asegurarModelo(
        marcaId: marcaId,
        nombre: 'Boxer CT100',
        cilindraje: 999,
      );
      expect((await marcas.obtenerModelos()).single.cilindraje, 100);
      expect(await marcas.obtenerModelos(), hasLength(1));
      expect(id, isNotNull);
    });

    test('un modelo sin nombre no se crea: el modelo es opcional', () async {
      final marcaId = await marcas.asegurarMarca('Yamaha');

      expect(await marcas.asegurarModelo(marcaId: marcaId, nombre: '  '),
          isNull);
      expect(await marcas.obtenerModelos(), isEmpty);
    });

    test('los modelos de una marca dada de baja no se ofrecen', () async {
      final marcaId = await marcas.asegurarMarca('Kymco');
      await marcas.crearModelo(marcaId: marcaId, nombre: 'Agility');
      await marcas.cambiarEstadoMarca(marcaId, activa: false);

      expect(await marcas.obtenerModelos(soloActivos: true), isEmpty);
      expect(await marcas.obtenerModelos(soloActivos: false), hasLength(1));
    });
  });

  group('compatibilidad de un repuesto', () {
    test('una línea vale por una marca o por un modelo, nunca por los dos',
        () async {
      // Lo garantiza el CHECK, no el código que llama.
      final marcaId = await marcas.asegurarMarca('Yamaha');
      final modeloId =
          (await marcas.asegurarModelo(marcaId: marcaId, nombre: 'FZ'))!;
      final productoId = await producto('SKU-1');

      expect(
        () => db.into(db.tablaProductoCompatibilidad).insert(
              TablaProductoCompatibilidadCompanion.insert(
                productoId: productoId,
                marcaId: Value(marcaId),
                modeloId: Value(modeloId),
              ),
            ),
        throwsA(isA<Exception>()),
      );
      expect(
        () => db.into(db.tablaProductoCompatibilidad).insert(
              TablaProductoCompatibilidadCompanion.insert(
                productoId: productoId,
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('el filtro por moto trae lo del modelo Y lo de toda su marca',
        () async {
      // Es la razón de que la compatibilidad admita los dos niveles: el aceite
      // sirve para cualquier Yamaha, la pastilla solo para la FZ.
      //
      // Va contra `observarPagina` y no contra un método aparte a propósito:
      // el `WHERE`, el `COUNT` y el `LIMIT` tienen que salir de la **misma**
      // consulta, o el total de la paginación contaría lo que la página ya no
      // muestra (`REGLAS_BD.md` §5).
      final yamaha = await marcas.asegurarMarca('Yamaha');
      final fz = (await marcas.asegurarModelo(marcaId: yamaha, nombre: 'FZ'))!;
      final mt = (await marcas.asegurarModelo(marcaId: yamaha, nombre: 'MT'))!;
      final honda = await marcas.asegurarMarca('Honda');

      final aceite = await producto('ACEITE');
      final pastilla = await producto('PASTILLA');
      final ajeno = await producto('AJENO');

      await compat.agregarMarca(productoId: aceite, marcaId: yamaha);
      await compat.agregarModelo(productoId: pastilla, modeloId: fz);
      await compat.agregarMarca(productoId: ajeno, marcaId: honda);

      Future<Set<int>> paraMoto({required int marcaId, int? modeloId}) async {
        final pagina = await productos
            .observarPagina(
              filtro: FiltroProductos(
                compatibleConMarcaId: marcaId,
                compatibleConModeloId: modeloId,
              ),
              pagina: 0,
              tamano: 50,
            )
            .first;
        return pagina.items.map((p) => p.id!).toSet();
      }

      expect(await paraMoto(marcaId: yamaha, modeloId: fz), {aceite, pastilla});
      // Otra Yamaha: el aceite sí, la pastilla de la FZ no.
      expect(await paraMoto(marcaId: yamaha, modeloId: mt), {aceite});
      // Una moto sin modelo catalogado se queda con lo de la marca.
      expect(await paraMoto(marcaId: yamaha), {aceite});
      // Sin marca el filtro no se aplica: salen los tres.
      expect(
        (await productos
                .observarPagina(
                  filtro: const FiltroProductos(),
                  pagina: 0,
                  tamano: 50,
                )
                .first)
            .items
            .length,
        3,
      );
    });

    test('el total de la paginación respeta el filtro por moto', () async {
      // Lo que rompería si el cruce se resolviera en Dart: la página traería
      // dos y el contador seguiría diciendo cinco.
      final yamaha = await marcas.asegurarMarca('Yamaha');
      for (var i = 0; i < 5; i++) {
        final id = await producto('SKU-$i');
        if (i < 2) await compat.agregarMarca(productoId: id, marcaId: yamaha);
      }

      final pagina = await productos
          .observarPagina(
            filtro: FiltroProductos(compatibleConMarcaId: yamaha),
            pagina: 0,
            tamano: 50,
          )
          .first;

      expect(pagina.total, 2);
      expect(pagina.items, hasLength(2));
    });

    test('la misma compatibilidad no se declara dos veces', () async {
      // La `UNIQUE` de la tabla no basta: SQLite trata cada NULL como
      // distinto, así que dos filas (7, NULL, 3) no chocan entre sí.
      final yamaha = await marcas.asegurarMarca('Yamaha');
      final fz = (await marcas.asegurarModelo(marcaId: yamaha, nombre: 'FZ'))!;
      final productoId = await producto('SKU-1');

      expect(
        await compat.agregarModelo(productoId: productoId, modeloId: fz),
        isA<Exito>(),
      );
      final repetida =
          await compat.agregarModelo(productoId: productoId, modeloId: fz);

      expect((repetida as Fallo).motivo, MotivoFallo.nombreDuplicado);
      expect(await compat.obtenerDeProducto(productoId), hasLength(1));
    });

    test('la marca se resuelve por los dos caminos del JOIN', () async {
      // La línea de modelo no guarda `marca_id`: su marca sale del modelo. Si
      // el alias del JOIN estuviera mal, esta etiqueta saldría sin marca.
      final yamaha = await marcas.asegurarMarca('Yamaha');
      final fz = (await marcas.asegurarModelo(marcaId: yamaha, nombre: 'FZ'))!;
      final productoId = await producto('SKU-1');

      await compat.agregarMarca(productoId: productoId, marcaId: yamaha);
      await compat.agregarModelo(productoId: productoId, modeloId: fz);

      final lineas = await compat.obtenerDeProducto(productoId);
      expect(
        lineas.map((c) => c.etiqueta),
        containsAll(['Yamaha (toda la marca)', 'Yamaha FZ']),
      );
    });

    test('borrar el producto se lleva sus compatibilidades', () async {
      // `cascade`: no es un documento contable, es una etiqueta del catálogo.
      final yamaha = await marcas.asegurarMarca('Yamaha');
      final productoId = await producto('SKU-1');
      await compat.agregarMarca(productoId: productoId, marcaId: yamaha);

      await (db.delete(db.tablaProducto)
            ..where((t) => t.id.equals(productoId)))
          .go();

      expect(
        await db.select(db.tablaProductoCompatibilidad).get(),
        isEmpty,
      );
    });

    test('sin permiso de editar productos no se declara nada', () async {
      final mirona = await sesionDePrueba(
        db,
        permisos: {Permiso.productosVer},
        usuario: 'mirona',
      );
      final yamaha = await marcas.asegurarMarca('Yamaha');
      final productoId = await producto('SKU-1');

      final resultado = await RepositorioCompatibilidadesImpl(db, mirona)
          .agregarMarca(productoId: productoId, marcaId: yamaha);

      expect((resultado as Fallo).motivo, MotivoFallo.validacion);
      expect(await compat.obtenerDeProducto(productoId), isEmpty);
    });
  });

  group('código de barras', () {
    test('dos productos sin código conviven; dos con el mismo, no', () async {
      // `UNIQUE` con varios NULL es legal en SQLite, y es justo lo que hace
      // falta: casi todo lo que llega a granel no trae código.
      await producto('SKU-1');
      await producto('SKU-2');

      await producto('SKU-3', codigoBarras: '7702001234567');
      expect(
        () => producto('SKU-4', codigoBarras: '7702001234567'),
        throwsA(isA<Exception>()),
      );
    });

    test('un código vacío se rechaza en vez de colarse como cadena', () async {
      // Sin el CHECK, dos productos «sin código» chocarían entre sí por la
      // cadena vacía en lugar de convivir como NULL.
      expect(
        () => producto('SKU-5', codigoBarras: '   '),
        throwsA(isA<Exception>()),
      );
    });
  });
}
