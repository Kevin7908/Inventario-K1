import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/inventario/repositorio/repositorio_inventario_impl.dart';
import 'package:inventario_k1/backend/features/ordenes/enum/enum_ordenes.dart';
import 'package:inventario_k1/backend/features/ordenes/modelo/orden_resumen.dart';
import 'package:inventario_k1/backend/features/ordenes/repositorio/repositorio_ordenes.dart';
import 'package:inventario_k1/backend/features/ordenes/repositorio/repositorio_ordenes_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/datos_taller.dart';
import 'soporte/sesion_de_prueba.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';

late AppDb db;

/// Quien firma lo que escriben estos tests. Ver `sesionDePrueba`.
late SesionActual sesion;
late RepositorioOrdenesImpl ordenes;
late RepositorioInventarioImpl inventario;
late DatosTaller taller;

Future<double> _stock() async {
  final fila = await db
      .customSelect('SELECT stock_actual AS s FROM productos WHERE id = '
          '${taller.productoId}')
      .getSingle();
  return fila.read<double>('s');
}

Future<int> _orden() async {
  final resumen = await ordenes.agregar(
    motoId: taller.motoId,
    clienteId: taller.clienteId,
    kilometrajeEntrada: 15000,
    diagnostico: 'No enciende',
  );
  return resumen.id;
}

void main() {
  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
    ordenes = RepositorioOrdenesImpl(db, sesion);
    inventario = RepositorioInventarioImpl(db, sesion);
    taller = await sembrarTaller(db);
  });

  tearDown(() => db.close());

  group('el SQL crudo sigue cuadrando con el esquema', () {
    // Mismo motivo que en facturas: estas consultas leían `c.nombres` y
    // `t.nombres`, que se mudaron a `personas`, y nada las revisaba.
    test('el resumen trae el nombre del cliente desde personas', () async {
      await _orden();

      final lista = await ordenes.obtenerTodas();

      expect(lista, hasLength(1));
      expect(lista.single.clienteNombre, 'Carlos Ramírez');
      expect(lista.single.motoDescripcion, contains('Pulsar'));
    });

    test('el detalle trae el nombre del técnico desde personas', () async {
      final ordenId = await _orden();
      await ordenes.agregarTarea(
        ordenId: ordenId,
        servicioId: taller.servicioId,
        tecnicoId: taller.tecnicoId,
        precioPactado: 50000,
      );

      final detalle = await ordenes.obtenerDetalle(ordenId);

      expect(detalle.tareas.single.tecnicoNombre, 'Ana Torres');
      expect(detalle.tareas.single.servicioNombre, 'Sincronización');
      expect(detalle.tareas.single.precioPactado, 50000);
    });
  });

  group('el inventario se mueve al anotar el repuesto', () {
    // Regla de negocio: anotar un repuesto en una orden **es** sacarlo del
    // estante, igual que en `reservas`. La pieza queda apartada para esa moto
    // aunque el mecánico todavía no la haya montado, así que el error por
    // falta de stock llega al agregar la línea y no media hora después, al
    // cerrar. Anular la orden es lo único que devuelve las piezas.

    Future<void> cerrar(int ordenId, {EstadoOrden a = EstadoOrden.lista}) =>
        ordenes.actualizar(
          id: ordenId,
          estado: a,
          kilometrajeEntrada: 15000,
        );

    test('agregar un repuesto descuenta al instante', () async {
      final ordenId = await _orden();

      await ordenes.agregarRepuesto(
        ordenId: ordenId,
        productoId: taller.productoId,
        cantidad: 2,
        precioUnitario: 30000,
      );

      expect(await _stock(), 8);
      final movimientos =
          await inventario.observarPorProducto(taller.productoId).first;
      expect(movimientos.where((m) => m.ordenId == ordenId), hasLength(1));
      expect((await ordenes.obtenerDetalle(ordenId)).repuestos, hasLength(1));
      expect(await inventario.descuadres(), isEmpty);
    });

    test('sin stock la línea no llega a existir', () async {
      // Antes esto se dejaba anotar y explotaba al cerrar. Ahora se rechaza en
      // el momento, con la orden todavía en la mano del usuario.
      final ordenId = await _orden();

      await expectLater(
        () => ordenes.agregarRepuesto(
          ordenId: ordenId,
          productoId: taller.productoId,
          cantidad: 99,
          precioUnitario: 30000,
        ),
        throwsA(isA<Exception>()),
      );

      expect(await _stock(), 10);
      expect(
        (await ordenes.obtenerDetalle(ordenId)).repuestos,
        isEmpty,
        reason: 'la transacción revierte la línea junto con el movimiento',
      );
    });

    test('dos líneas del mismo producto se descuentan una tras otra', () async {
      // Con stock 10, la primera de 6 pasa y deja 4; la segunda ya no cabe.
      // Antes las dos se anotaban y el choque aparecía al cerrar.
      final ordenId = await _orden();

      await ordenes.agregarRepuesto(
        ordenId: ordenId,
        productoId: taller.productoId,
        cantidad: 6,
        precioUnitario: 30000,
      );
      expect(await _stock(), 4);

      await expectLater(
        () => ordenes.agregarRepuesto(
          ordenId: ordenId,
          productoId: taller.productoId,
          cantidad: 6,
          precioUnitario: 30000,
        ),
        throwsA(isA<Exception>()),
      );

      expect(await _stock(), 4, reason: 'la segunda no movió nada');
      expect((await ordenes.obtenerDetalle(ordenId)).repuestos, hasLength(1));
    });

    test('cerrar la orden ya no descuenta nada', () async {
      final ordenId = await _orden();
      await ordenes.agregarRepuesto(
        ordenId: ordenId,
        productoId: taller.productoId,
        cantidad: 2,
        precioUnitario: 30000,
      );

      await cerrar(ordenId);
      expect(await _stock(), 8, reason: 'ya había salido al anotarlo');

      await cerrar(ordenId, a: EstadoOrden.entregada);
      expect(await _stock(), 8);
      expect(await inventario.descuadres(), isEmpty);
    });

    test('subir la cantidad saca solo la diferencia', () async {
      final ordenId = await _orden();
      await ordenes.agregarRepuesto(
        ordenId: ordenId,
        productoId: taller.productoId,
        cantidad: 2,
        precioUnitario: 30000,
      );
      final detalle = await ordenes.obtenerDetalle(ordenId);

      await ordenes.actualizarRepuesto(detalle.repuestos.single.id, cantidad: 5);

      expect(await _stock(), 5, reason: '10 - 2 - 3, no 10 - 2 - 5');
      expect(await inventario.descuadres(), isEmpty);
    });

    test('bajar la cantidad devuelve la diferencia', () async {
      final ordenId = await _orden();
      await ordenes.agregarRepuesto(
        ordenId: ordenId,
        productoId: taller.productoId,
        cantidad: 5,
        precioUnitario: 30000,
      );
      final detalle = await ordenes.obtenerDetalle(ordenId);

      await ordenes.actualizarRepuesto(detalle.repuestos.single.id, cantidad: 2);

      expect(await _stock(), 8);
      expect(await inventario.descuadres(), isEmpty);
    });

    test('subir la cantidad más allá del stock se rechaza', () async {
      final ordenId = await _orden();
      await ordenes.agregarRepuesto(
        ordenId: ordenId,
        productoId: taller.productoId,
        cantidad: 2,
        precioUnitario: 30000,
      );
      final detalle = await ordenes.obtenerDetalle(ordenId);

      await expectLater(
        () => ordenes.actualizarRepuesto(
          detalle.repuestos.single.id,
          cantidad: 99,
        ),
        throwsA(isA<Exception>()),
      );

      expect(await _stock(), 8, reason: 'quedan las 2 de la línea original');
      final vigente = await ordenes.obtenerDetalle(ordenId);
      expect(vigente.repuestos.single.cantidad, 2,
          reason: 'la cantidad tampoco se guardó');
    });

    test('quitar la línea devuelve la pieza', () async {
      final ordenId = await _orden();
      await ordenes.agregarRepuesto(
        ordenId: ordenId,
        productoId: taller.productoId,
        cantidad: 2,
        precioUnitario: 30000,
      );
      final detalle = await ordenes.obtenerDetalle(ordenId);

      await ordenes.eliminarRepuesto(detalle.repuestos.single.id);

      expect(await _stock(), 10);
      expect(await inventario.descuadres(), isEmpty);
    });

    test('poner y quitar deja los dos movimientos en el libro mayor', () async {
      // Es el precio aceptado del cambio: el estante se movió de verdad dos
      // veces, así que el historial lo registra. A cambio, `stock_actual`
      // nunca miente mientras la orden se arma.
      final ordenId = await _orden();
      await ordenes.agregarRepuesto(
        ordenId: ordenId,
        productoId: taller.productoId,
        cantidad: 2,
        precioUnitario: 30000,
      );
      final detalle = await ordenes.obtenerDetalle(ordenId);
      await ordenes.eliminarRepuesto(detalle.repuestos.single.id);

      final movimientos =
          await inventario.observarPorProducto(taller.productoId).first;
      expect(movimientos.where((m) => m.ordenId == ordenId), hasLength(2));
      expect(await _stock(), 10);
    });

    test('anular devuelve todo lo que la orden tenía anotado', () async {
      final ordenId = await _orden();
      await ordenes.agregarRepuesto(
        ordenId: ordenId,
        productoId: taller.productoId,
        cantidad: 3,
        precioUnitario: 30000,
      );
      expect(await _stock(), 7);

      await ordenes.actualizar(
        id: ordenId,
        estado: EstadoOrden.anulada,
        kilometrajeEntrada: 15000,
      );

      expect(await _stock(), 10);
      expect(await inventario.descuadres(), isEmpty);
    });

    test('anular una orden abierta también devuelve', () async {
      // Antes no devolvía nada porque nada había salido. Ahora sí salió.
      final ordenId = await _orden();
      await ordenes.agregarRepuesto(
        ordenId: ordenId,
        productoId: taller.productoId,
        cantidad: 3,
        precioUnitario: 30000,
      );

      await ordenes.actualizar(
        id: ordenId,
        estado: EstadoOrden.anulada,
        kilometrajeEntrada: 15000,
      );

      expect(await _stock(), 10);
      expect(await inventario.descuadres(), isEmpty);
    });

    test('anular dos veces no devuelve dos veces', () async {
      // Sin la guarda de la transición, la segunda anulación inflaría el
      // inventario con piezas que nunca existieron.
      final ordenId = await _orden();
      await ordenes.agregarRepuesto(
        ordenId: ordenId,
        productoId: taller.productoId,
        cantidad: 3,
        precioUnitario: 30000,
      );

      for (var i = 0; i < 2; i++) {
        await ordenes.actualizar(
          id: ordenId,
          estado: EstadoOrden.anulada,
          kilometrajeEntrada: 15000,
        );
      }

      expect(await _stock(), 10);
      expect(await inventario.descuadres(), isEmpty);
    });
  });

  group('las guardas de la base', () {
    test('una orden entregada no admite más repuestos', () async {
      final ordenId = await _orden();
      await ordenes.actualizar(
        id: ordenId,
        estado: EstadoOrden.entregada,
        kilometrajeEntrada: 15000,
      );

      expect(
        () => ordenes.agregarRepuesto(
          ordenId: ordenId,
          productoId: taller.productoId,
          cantidad: 1,
          precioUnitario: 30000,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('una orden anulada no admite más tareas', () async {
      final ordenId = await _orden();
      await ordenes.actualizar(
        id: ordenId,
        estado: EstadoOrden.anulada,
        kilometrajeEntrada: 15000,
      );

      expect(
        () => ordenes.agregarTarea(
          ordenId: ordenId,
          servicioId: taller.servicioId,
          tecnicoId: taller.tecnicoId,
          precioPactado: 50000,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('los CHECK del esquema', () {
    test('un estado inventado se rechaza', () async {
      final ordenId = await _orden();

      expect(
        () => db.customStatement(
            "UPDATE ordenes_servicio SET estado = 'EN_PAUSA' WHERE id = "
            '$ordenId'),
        throwsA(isA<Exception>()),
      );
    });

    test('un kilometraje negativo se rechaza', () async {
      expect(
        () => ordenes.agregar(
          motoId: taller.motoId,
          clienteId: taller.clienteId,
          kilometrajeEntrada: -1,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('no se borra un producto montado en una moto', () async {
      final ordenId = await _orden();
      await ordenes.agregarRepuesto(
        ordenId: ordenId,
        productoId: taller.productoId,
        cantidad: 1,
        precioUnitario: 30000,
      );

      expect(
        () => db.customStatement(
            'DELETE FROM productos WHERE id = ${taller.productoId}'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('el número de orden sale del consecutivo, no del id', () {
    // Antes el mapper armaba `'#ORD-' + id`. Eso deja huecos —un INSERT
    // fallido se salta un número para siempre— y ata el número visible a un
    // detalle interno de SQLite (§7.1 de las reglas de base de datos).

    test('la primera orden es ORD-0001 y la serie sigue', () async {
      final primera = await ordenes.agregar(
        motoId: taller.motoId,
        clienteId: taller.clienteId,
        kilometrajeEntrada: 100,
      );
      final segunda = await ordenes.agregar(
        motoId: taller.motoId,
        clienteId: taller.clienteId,
        kilometrajeEntrada: 200,
      );

      expect(primera.numeroOrden, 'ORD-0001');
      expect(segunda.numeroOrden, 'ORD-0002');
    });

    test('el número no se repite', () async {
      final id = await _orden();
      final numero = (await ordenes.obtenerDetalle(id)).numeroOrden;

      expect(
        () => db.customStatement(
          'INSERT INTO ordenes_servicio (numero, moto_id, cliente_id, '
          'kilometraje_entrada) VALUES (?, ?, ?, ?)',
          [numero, taller.motoId, taller.clienteId, 100],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('el número es una columna guardada, no algo derivado del id', () async {
      final id = await _orden();

      // Lo que sí se puede comprobar: el número vive en la tabla y sale de
      // `consecutivos`, no de una expresión sobre el `id`.
      final fila = await db
          .customSelect('SELECT numero FROM ordenes_servicio WHERE id = ?',
              variables: [Variable.withInt(id)])
          .getSingle();
      expect(fila.read<String>('numero'), 'ORD-0001');

      final serie = await db
          .customSelect("SELECT ultimo FROM consecutivos "
              "WHERE documento = 'ORDEN'")
          .getSingleOrNull();
      expect(serie?.read<int>('ultimo'), 1,
          reason: 'la serie ORD avanzó al crear la orden');
    });

    // NO PROBADO, y conviene saberlo: que la serie **no deje huecos** cuando
    // un `INSERT` falla no se puede verificar desde aquí. Un
    // `INTEGER PRIMARY KEY AUTOINCREMENT` revierte su secuencia junto con la
    // transacción, así que en un test el `id` y el consecutivo avanzan igual.
    // La diferencia aparece con `VACUUM`, con una restauración parcial o si
    // alguien borra filas a mano —cosas que no ocurren dentro de un test—.
    // El cambio se hace porque §7.1 lo exige, no porque un test lo obligue.
  });

  group('los totales del listado los suma SQLite', () {
    Future<OrdenResumen> resumenDe(int id) async {
      final lista = await ordenes.obtenerTodas();
      return lista.firstWhere((o) => o.id == id);
    }

    test('suma mano de obra, repuestos y cargos por separado', () async {
      final id = await _orden();
      await ordenes.agregarTarea(
        ordenId: id,
        servicioId: taller.servicioId,
        tecnicoId: taller.tecnicoId,
        precioPactado: 50000,
      );
      await ordenes.agregarRepuesto(
        ordenId: id,
        productoId: taller.productoId,
        cantidad: 2,
        precioUnitario: 30000,
      );
      await ordenes.agregarCargo(
        ordenId: id,
        descripcion: 'Domicilio',
        precio: 8000,
      );

      final resumen = await resumenDe(id);
      expect(resumen.subtotalManoObra, 50000);
      expect(resumen.subtotalRepuestos, 60000);
      expect(resumen.subtotalCargos, 8000);
      expect(resumen.total, 118000);
    });

    test('con varias tareas y repuestos a la vez no se infla nada', () async {
      // Por qué los subtotales van en subconsultas correlacionadas y no en un
      // JOIN + GROUP BY: con dos tablas hijas a la vez el JOIN multiplica
      // filas y cada importe se cuenta tantas veces como filas de la otra
      // tabla haya. El segundo `expect` de este test ejecuta la versión
      // ingenua contra los mismos datos para dejarlo por escrito.
      final id = await _orden();
      for (var i = 0; i < 2; i++) {
        await ordenes.agregarTarea(
          ordenId: id,
          servicioId: taller.servicioId,
          tecnicoId: taller.tecnicoId,
          precioPactado: 10000,
        );
        await ordenes.agregarRepuesto(
          ordenId: id,
          productoId: taller.productoId,
          cantidad: 1,
          precioUnitario: 5000,
        );
      }

      final resumen = await resumenDe(id);
      expect(resumen.subtotalManoObra, 20000);
      expect(resumen.subtotalRepuestos, 10000);
      expect(resumen.total, 30000);

      // La versión ingenua, sobre los mismos datos: 2 tareas x 2 repuestos =
      // cada importe contado cuatro veces. 20.000 -> 40.000 y 10.000 -> 20.000.
      final ingenua = await db.customSelect('''
        SELECT
          COALESCE(SUM(ot.precio_pactado), 0) AS mano_obra,
          COALESCE(SUM(CAST(ROUND(orp.cantidad * orp.precio_unitario) AS INTEGER)), 0) AS repuestos
        FROM ordenes_servicio os
        LEFT JOIN ordenes_tareas    ot  ON ot.orden_id  = os.id
        LEFT JOIN ordenes_repuestos orp ON orp.orden_id = os.id
        WHERE os.id = ?
        GROUP BY os.id
      ''', variables: [Variable.withInt(id)]).getSingle();

      expect(ingenua.read<int>('mano_obra'), 40000,
          reason: 'el JOIN duplica cada tarea por cada repuesto');
      expect(ingenua.read<int>('repuestos'), 20000);
    });

    test('una orden sin líneas suma cero, no null', () async {
      final resumen = await resumenDe(await _orden());
      expect(resumen.total, 0);
      expect(resumen.tecnicoParaListado, 'Sin asignar');
    });

    test('la columna de técnico dice el nombre, o "Varios"', () async {
      final id = await _orden();
      await ordenes.agregarTarea(
        ordenId: id,
        servicioId: taller.servicioId,
        tecnicoId: taller.tecnicoId,
        precioPactado: 10000,
      );

      expect((await resumenDe(id)).tecnicoParaListado, 'Ana Torres');

      // Un segundo técnico en la misma orden.
      final otraPersona = await db.into(db.tablaPersona).insert(
            TablaPersonaCompanion.insert(
              nombres: 'Luis',
              apellidos: const Value('Pérez'),
              documento: const Value('555111'),
            ),
          );
      final otroTecnico = await db
          .into(db.tablaTecnico)
          .insert(TablaTecnicoCompanion.insert(personaId: otraPersona));
      await ordenes.agregarTarea(
        ordenId: id,
        servicioId: taller.servicioId,
        tecnicoId: otroTecnico,
        precioPactado: 10000,
      );

      expect((await resumenDe(id)).tecnicoParaListado, 'Varios');
    });

    test('el resumen cuenta cada estado con COUNT, no en memoria', () async {
      final abierta = await _orden();
      final lista = await _orden();
      await ordenes.actualizar(
        id: lista,
        estado: EstadoOrden.lista,
        kilometrajeEntrada: 15000,
      );

      final resumen = await ordenes.observarResumen().first;
      expect(resumen.total, 2);
      expect(resumen.enProceso, 1);
      expect(resumen.pendientes, 1);
      expect(resumen.completadas, 0);
      expect(abierta, isNotNull);
    });
  });

  group('descuento de la orden', () {
    Future<OrdenResumen> resumenDe(int id) async =>
        (await ordenes.obtenerTodas()).firstWhere((o) => o.id == id);

    Future<int> ordenCon({required int precioTarea}) async {
      final id = await _orden();
      await ordenes.agregarTarea(
        ordenId: id,
        servicioId: taller.servicioId,
        tecnicoId: taller.tecnicoId,
        precioPactado: precioTarea,
      );
      return id;
    }

    test('se resta del total, sin sumarle IVA después', () async {
      final id = await ordenCon(precioTarea: 100000);
      await ordenes.fijarDescuento(id: id, valor: 20000);

      // Los precios ya traen el IVA dentro, así que rebajar 20.000 rebaja
      // exactamente eso de lo que paga el cliente.
      final resumen = await resumenDe(id);
      expect(resumen.descuento, 20000);
      expect(resumen.total, 80000);
    });

    test('un descuento mayor que el subtotal se recorta', () async {
      // Aquí no hay CHECK que lo atrape: el subtotal no es una columna, sino
      // la suma de tres tablas. Este recorte es la única garantía.
      final id = await ordenCon(precioTarea: 30000);
      await ordenes.fijarDescuento(id: id, valor: 900000);

      expect((await resumenDe(id)).descuento, 30000);
      expect((await resumenDe(id)).total, 0);
    });

    test('un descuento negativo queda en cero', () async {
      final id = await ordenCon(precioTarea: 30000);
      await ordenes.fijarDescuento(id: id, valor: -7000);

      expect((await resumenDe(id)).descuento, 0);
    });

    test('quitar una línea recorta el descuento que dejó de caber', () async {
      final id = await ordenCon(precioTarea: 30000);
      await ordenes.agregarCargo(
        ordenId: id,
        descripcion: 'Domicilio',
        precio: 20000,
      );
      await ordenes.fijarDescuento(id: id, valor: 45000);
      expect((await resumenDe(id)).descuento, 45000);

      final detalle = await ordenes.obtenerDetalle(id);
      await ordenes.eliminarCargo(detalle.cargos.single.id);

      final resumen = await resumenDe(id);
      expect(resumen.subtotal, 30000);
      expect(resumen.descuento, 30000, reason: 'recortado al nuevo subtotal');
      expect(resumen.total, 0);
    });

    test('quitar un repuesto también lo recorta', () async {
      final id = await _orden();
      await ordenes.agregarRepuesto(
        ordenId: id,
        productoId: taller.productoId,
        cantidad: 2,
        precioUnitario: 20000,
      );
      await ordenes.fijarDescuento(id: id, valor: 40000);

      final detalle = await ordenes.obtenerDetalle(id);
      await ordenes.eliminarRepuesto(detalle.repuestos.single.id);

      final resumen = await resumenDe(id);
      expect(resumen.subtotal, 0);
      expect(resumen.descuento, 0);
      expect(resumen.total, 0);
    });
  });

  group('cargos sueltos', () {
    test('se guardan y entran en el total sin tocar el inventario', () async {
      final id = await _orden();
      final stockAntes = await _stock();

      await ordenes.agregarCargo(
        ordenId: id,
        descripcion: 'Repuesto comprado afuera',
        precio: 45000,
      );

      final detalle = await ordenes.obtenerDetalle(id);
      expect(detalle.cargos, hasLength(1));
      expect(detalle.cargos.single.descripcion, 'Repuesto comprado afuera');
      expect(detalle.subtotalCargos, 45000);
      expect(detalle.total, 45000);
      expect(await _stock(), stockAntes,
          reason: 'un cargo suelto no está en el catálogo, no mueve stock');
    });

    test('un cargo sin descripción se rechaza', () async {
      final id = await _orden();

      await expectLater(
        () => ordenes.agregarCargo(ordenId: id, descripcion: '   ', precio: 100),
        throwsA(isA<Exception>()),
      );
      expect((await ordenes.obtenerDetalle(id)).cargos, isEmpty);
    });

    test('el CHECK rechaza un precio negativo', () async {
      final id = await _orden();

      expect(
        () => db.customStatement(
          'INSERT INTO ordenes_cargos (orden_id, descripcion, precio) '
          'VALUES (?, ?, ?)',
          [id, 'Trampa', -500],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('borrar la orden se lleva sus cargos en cascada', () async {
      final id = await _orden();
      await ordenes.agregarCargo(ordenId: id, descripcion: 'X', precio: 1000);

      await ordenes.eliminar(id);

      final quedan = await db
          .customSelect('SELECT COUNT(*) AS n FROM ordenes_cargos')
          .getSingle();
      expect(quedan.read<int>('n'), 0);
    });
  });

  group('el listado se pagina en SQL', () {
    // §5: el WHERE, el COUNT y el LIMIT los resuelve SQLite. Antes el listado
    // traía todas las órdenes y el recorte se hacía en Dart, así que cada
    // tecla del buscador recorría el histórico entero del taller.

    /// Un segundo cliente con su moto, para que la búsqueda tenga de dónde
    /// distinguir.
    Future<int> otraMoto({
      required String nombres,
      required String apellidos,
      required String documento,
      required String marca,
      required String modelo,
      required String placa,
    }) async {
      final persona = await db.into(db.tablaPersona).insert(
            TablaPersonaCompanion.insert(
              nombres: nombres,
              apellidos: Value(apellidos),
              documento: Value(documento),
            ),
          );
      final cliente = await db
          .into(db.tablaCliente)
          .insert(TablaClienteCompanion.insert(personaId: persona));
      return db.into(db.tablaMoto).insert(
            TablaMotoCompanion.insert(
              clienteId: cliente,
              marca: marca,
              modelo: modelo,
              placa: Value(placa),
            ),
          );
    }

    Future<void> sembrar(int cuantas) async {
      for (var i = 0; i < cuantas; i++) {
        await _orden();
      }
    }

    Future<PaginaOrdenes> pagina(
      int indice, {
      int tamano = 5,
      FiltroOrdenes filtro = const FiltroOrdenes(),
    }) =>
        ordenes
            .observarPagina(filtro: filtro, pagina: indice, tamano: tamano)
            .first;

    test('el LIMIT recorta la página pero el total sigue siendo el real',
        () async {
      await sembrar(12);

      final primera = await pagina(0);

      expect(primera.items, hasLength(5), reason: 'el LIMIT es de 5');
      expect(primera.total, 12, reason: 'el COUNT ignora el LIMIT');
    });

    test('el OFFSET avanza sin repetir ni saltarse órdenes', () async {
      await sembrar(12);

      final vistas = <String>[];
      for (var i = 0; i < 3; i++) {
        vistas.addAll((await pagina(i)).items.map((o) => o.numeroOrden));
      }

      expect(vistas, hasLength(12));
      expect(vistas.toSet(), hasLength(12), reason: 'ninguna se repite');
      // La última página queda corta, no vacía ni desbordada.
      expect((await pagina(2)).items, hasLength(2));
    });

    test('el filtro de estado recorta en SQL y el total lo acompaña',
        () async {
      await sembrar(4);
      final cerrada = await _orden();
      await ordenes.actualizar(
        id: cerrada,
        estado: EstadoOrden.entregada,
        kilometrajeEntrada: 15000,
      );

      final entregadas = await pagina(
        0,
        filtro: const FiltroOrdenes(estado: EstadoOrden.entregada),
      );

      expect(entregadas.total, 1);
      expect(entregadas.items.single.id, cerrada);
    });

    test('la búsqueda mira número, cliente, moto y placa', () async {
      await _orden(); // Carlos Ramírez, Bajaj Pulsar, KMN12C
      final motoLucia = await otraMoto(
        nombres: 'Lucía',
        apellidos: 'Peña',
        documento: '555000111',
        marca: 'Honda',
        modelo: 'CB190',
        placa: 'XYZ99A',
      );
      final deLucia = await ordenes.agregar(
        motoId: motoLucia,
        clienteId: (await db
                .customSelect('SELECT cliente_id AS c FROM motos WHERE id = ?',
                    variables: [Variable.withInt(motoLucia)])
                .getSingle())
            .read<int>('c'),
        kilometrajeEntrada: 100,
      );

      Future<List<int>> buscar(String texto) async =>
          (await pagina(0, filtro: FiltroOrdenes(busqueda: texto)))
              .items
              .map((o) => o.id)
              .toList();

      expect(await buscar('lucía'), [deLucia.id], reason: 'por cliente');
      expect(await buscar('honda'), [deLucia.id], reason: 'por marca');
      expect(await buscar('cb190'), [deLucia.id], reason: 'por modelo');
      expect(await buscar('xyz99'), [deLucia.id], reason: 'por placa');
      expect(await buscar(deLucia.numeroOrden), [deLucia.id],
          reason: 'por número');
    });

    test('el total del filtro cuenta todas las coincidencias, no la página',
        () async {
      await sembrar(8);

      final resultado = await pagina(
        0,
        tamano: 3,
        filtro: const FiltroOrdenes(estado: EstadoOrden.abierta),
      );

      expect(resultado.items, hasLength(3));
      expect(resultado.total, 8);
    });

    test('la búsqueda con comilla simple no rompe la consulta', () async {
      // El SQL crudo va con parámetros, no interpolando: §5 avisa de que a
      // estas consultas no las revisa el analizador.
      await sembrar(2);

      final resultado = await pagina(
        0,
        filtro: const FiltroOrdenes(busqueda: "O'Brien"),
      );

      expect(resultado.total, 0);
      expect(resultado.items, isEmpty);
    });

    test('la búsqueda y el estado se aplican juntos', () async {
      final abierta = await _orden();
      final entregada = await _orden();
      await ordenes.actualizar(
        id: entregada,
        estado: EstadoOrden.entregada,
        kilometrajeEntrada: 15000,
      );

      final resultado = await pagina(
        0,
        filtro: const FiltroOrdenes(
          busqueda: 'carlos',
          estado: EstadoOrden.abierta,
        ),
      );

      expect(resultado.total, 1);
      expect(resultado.items.single.id, abierta);
    });

    test('la página trae los subtotales ya resueltos, como el listado entero',
        () async {
      final id = await _orden();
      await ordenes.agregarTarea(
        ordenId: id,
        servicioId: taller.servicioId,
        tecnicoId: taller.tecnicoId,
        precioPactado: 50000,
      );
      await ordenes.agregarCargo(
        ordenId: id,
        descripcion: 'Domicilio',
        precio: 8000,
      );

      final fila = (await pagina(0)).items.single;

      expect(fila.subtotalManoObra, 50000);
      expect(fila.subtotalCargos, 8000);
      expect(fila.tecnicoParaListado, 'Ana Torres');
    });
  });
}
