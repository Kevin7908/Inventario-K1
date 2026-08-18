import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/inventario/repositorio/repositorio_inventario_impl.dart';
import 'package:inventario_k1/backend/features/ventas/ordenes/enum/enum_ordenes.dart';
import 'package:inventario_k1/backend/features/ventas/ordenes/repositorio/repositrio_ordenes_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/datos_taller.dart';

late AppDb db;
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
    ordenes = RepositorioOrdenesImpl(db);
    inventario = RepositorioInventarioImpl(db);
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

  group('los repuestos mueven el inventario por el libro mayor', () {
    test('agregar un repuesto descuenta y deja su movimiento', () async {
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
      expect(movimientos.first.ordenId, ordenId);
      expect(await inventario.descuadres(), isEmpty);
    });

    test('quitarlo lo devuelve', () async {
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

    test('sin stock no queda ni la línea ni el movimiento', () async {
      final ordenId = await _orden();

      await expectLater(
        ordenes.agregarRepuesto(
          ordenId: ordenId,
          productoId: taller.productoId,
          cantidad: 99,
          precioUnitario: 30000,
        ),
        throwsA(isA<Exception>()),
      );

      final detalle = await ordenes.obtenerDetalle(ordenId);
      expect(detalle.repuestos, isEmpty);
      expect(await _stock(), 10);
    });

    test('cambiar la cantidad solo mueve la diferencia', () async {
      final ordenId = await _orden();
      await ordenes.agregarRepuesto(
        ordenId: ordenId,
        productoId: taller.productoId,
        cantidad: 2,
        precioUnitario: 30000,
      );
      final detalle = await ordenes.obtenerDetalle(ordenId);

      await ordenes.actualizarRepuesto(
        detalle.repuestos.single.id,
        cantidad: 5,
      );

      expect(await _stock(), 5);
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
}
