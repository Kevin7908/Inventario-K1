import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/inventario/repositorio/repositorio_inventario_impl.dart';
import 'package:inventario_k1/backend/features/ventas/facturas/enum/enum_facturas.dart';
import 'package:inventario_k1/backend/features/ventas/facturas/repositorio/repositorio_facturas_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/datos_taller.dart';

late AppDb db;
late RepositorioFacturasImpl facturas;
late RepositorioInventarioImpl inventario;
late DatosTaller taller;

Future<double> _stock() async {
  final fila = await db
      .customSelect('SELECT stock_actual AS s FROM productos WHERE id = '
          '${taller.productoId}')
      .getSingle();
  return fila.read<double>('s');
}

/// Crea una factura de mostrador con una línea de producto.
Future<int> _facturaConProducto({double cantidad = 3}) async {
  final resumen = await facturas.crear(
    tipo: TipoVenta.mostrador,
    clienteId: taller.clienteId,
    metodoPago: MetodoPago.efectivo,
    estadoPago: EstadoPago.pendiente,
  );
  await facturas.agregarItem(
    ventaId: resumen.id,
    tipoItem: TipoItem.producto,
    productoId: taller.productoId,
    descripcion: 'Pastilla de freno',
    cantidad: cantidad,
    precioUnitario: 30000,
    costoUnitario: 18000,
  );
  return resumen.id;
}

void main() {
  setUp(() async {
    db = baseEnMemoria();
    facturas = RepositorioFacturasImpl(db);
    inventario = RepositorioInventarioImpl(db);
    taller = await sembrarTaller(db);
  });

  tearDown(() => db.close());

  group('el SQL crudo del resumen sigue cuadrando con el esquema', () {
    // Este grupo existe por un fallo real: al mover la identidad a `personas`,
    // estas consultas siguieron pidiendo `c.nombres` y compilaron igual —
    // `flutter analyze` no entra en un `customSelect`. Reventaban al abrir la
    // pantalla.
    test('la lista trae el nombre del cliente desde personas', () async {
      await _facturaConProducto();

      final lista = await facturas.obtenerTodas();

      expect(lista, hasLength(1));
      expect(lista.single.clienteNombre, 'Carlos Ramírez');
    });

    test('el detalle trae cabecera y líneas', () async {
      final id = await _facturaConProducto();

      final detalle = await facturas.obtenerDetalle(id);

      expect(detalle.clienteNombre, 'Carlos Ramírez');
      expect(detalle.items, hasLength(1));
      expect(detalle.items.single.descripcion, 'Pastilla de freno');
    });
  });

  group('importes en pesos enteros', () {
    test('el subtotal de la línea y el total de la factura son enteros',
        () async {
      final id = await _facturaConProducto(cantidad: 3);

      final detalle = await facturas.obtenerDetalle(id);

      expect(detalle.items.single.subtotal, 90000);
      expect(detalle.subtotal, 90000);
      expect(detalle.total, 90000);
    });

    test('una cantidad fraccionaria redondea al peso, no lo trunca', () async {
      // 0.5 × 30001 = 15000.5. Redondear da 15001; truncar daría 15000 y el
      // medio peso se perdería en cada línea.
      final resumen = await facturas.crear(
        tipo: TipoVenta.mostrador,
        clienteId: taller.clienteId,
        metodoPago: MetodoPago.efectivo,
        estadoPago: EstadoPago.pendiente,
      );
      await facturas.agregarItem(
        ventaId: resumen.id,
        tipoItem: TipoItem.producto,
        productoId: taller.productoId,
        descripcion: 'Pastilla de freno',
        cantidad: 0.5,
        precioUnitario: 30001,
      );

      final detalle = await facturas.obtenerDetalle(resumen.id);

      expect(detalle.items.single.subtotal, 15001);
      expect(detalle.total, 15001);
    });
  });

  group('anular, no borrar', () {
    test('la factura queda en ANULADA y el stock vuelve', () async {
      final id = await _facturaConProducto(cantidad: 3);
      expect(await _stock(), 7);

      await facturas.anular(id);

      final detalle = await facturas.obtenerDetalle(id);
      expect(detalle.estadoPago, EstadoPago.anulada);
      expect(await _stock(), 10);
      expect(await facturas.obtenerTodas(), hasLength(1));
    });

    test('la devolución queda en el libro mayor, no borra la salida',
        () async {
      final id = await _facturaConProducto(cantidad: 3);
      await facturas.anular(id);

      final movimientos =
          await inventario.observarPorProducto(taller.productoId).first;

      expect(movimientos, hasLength(3)); // inicial + salida + devolución
      expect(await inventario.descuadres(), isEmpty);
    });

    test('anular dos veces no se admite', () async {
      final id = await _facturaConProducto();
      await facturas.anular(id);

      expect(() => facturas.anular(id), throwsA(isA<Exception>()));
    });
  });

  group('atomicidad de las líneas', () {
    test('el chequeo de stock corta antes de insertar nada', () async {
      final resumen = await facturas.crear(
        tipo: TipoVenta.mostrador,
        clienteId: taller.clienteId,
        metodoPago: MetodoPago.efectivo,
        estadoPago: EstadoPago.pendiente,
      );

      await expectLater(
        facturas.agregarItem(
          ventaId: resumen.id,
          tipoItem: TipoItem.producto,
          productoId: taller.productoId,
          descripcion: 'Pastilla de freno',
          cantidad: 99,
          precioUnitario: 30000,
        ),
        throwsA(isA<Exception>()),
      );

      final detalle = await facturas.obtenerDetalle(resumen.id);
      expect(detalle.items, isEmpty);
      expect(await _stock(), 10);
    });

    test('si el recálculo del total falla, la línea y el stock vuelven',
        () async {
      // Factura cobrada por completo. Quitarle una línea bajaría el total por
      // debajo de lo ya pagado, y el `CHECK (total_pagado <= total)` lo
      // rechaza a mitad de la operación: es el fallo real que obliga a que
      // borrado, devolución de stock y recálculo vayan en una transacción.
      final id = await _facturaConProducto(cantidad: 3);
      await facturas.actualizarPago(
        id: id,
        totalPagado: 90000,
        estadoPago: EstadoPago.pagado,
        metodoPago: MetodoPago.efectivo,
      );

      final detalle = await facturas.obtenerDetalle(id);
      final itemId = detalle.items.single.id;

      await expectLater(
        facturas.eliminarItem(itemId),
        throwsA(isA<Exception>()),
      );

      final despues = await facturas.obtenerDetalle(id);
      expect(despues.items, hasLength(1), reason: 'la línea tiene que volver');
      expect(await _stock(), 7, reason: 'el stock no puede haberse devuelto');
      expect(await inventario.descuadres(), isEmpty);
    });
  });

  group('las guardas de la base', () {
    test('una factura no se puede borrar', () async {
      final id = await _facturaConProducto();

      expect(
        () => db.customStatement('DELETE FROM ventas WHERE id = $id'),
        throwsA(isA<Exception>()),
      );
    });

    test('una factura anulada no se puede modificar', () async {
      final id = await _facturaConProducto();
      await facturas.anular(id);

      expect(
        () => facturas.actualizar(
          id: id,
          metodoPago: MetodoPago.tarjeta,
          estadoPago: EstadoPago.pagado,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('a una factura anulada no se le agregan líneas', () async {
      final id = await _facturaConProducto();
      await facturas.anular(id);

      expect(
        () => facturas.agregarItem(
          ventaId: id,
          tipoItem: TipoItem.servicio,
          servicioId: taller.servicioId,
          descripcion: 'Sincronización',
          cantidad: 1,
          precioUnitario: 50000,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('los CHECK del esquema', () {
    test('un método de pago inventado se rechaza', () async {
      final id = await _facturaConProducto();

      expect(
        () => db.customStatement(
            "UPDATE ventas SET metodo_pago = 'BITCOIN' WHERE id = $id"),
        throwsA(isA<Exception>()),
      );
    });

    test('no se puede cobrar más de lo facturado', () async {
      final id = await _facturaConProducto(cantidad: 1);

      expect(
        () => db.customStatement(
            'UPDATE ventas SET total_pagado = 999999 WHERE id = $id'),
        throwsA(isA<Exception>()),
      );
    });

    test('una línea de producto sin producto_id se rechaza', () async {
      final id = await _facturaConProducto();

      expect(
        () => db.into(db.tablaVentaDetalles).insert(
              TablaVentaDetallesCompanion.insert(
                ventaId: id,
                tipoItem: 'PRODUCTO',
                descripcion: 'Fantasma',
                precioUnitario: 1000,
                subtotal: 1000,
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('una línea con cantidad cero se rechaza', () async {
      final id = await _facturaConProducto();

      expect(
        () => db.into(db.tablaVentaDetalles).insert(
              TablaVentaDetallesCompanion.insert(
                ventaId: id,
                tipoItem: 'SERVICIO',
                servicioId: Value(taller.servicioId),
                descripcion: 'Sincronización',
                cantidad: const Value(0),
                precioUnitario: 1000,
                subtotal: 0,
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('el número de factura no se repite', () async {
      final id = await _facturaConProducto();
      final numero =
          (await facturas.obtenerDetalle(id)).numeroFactura;

      expect(
        () => db.into(db.tablaVentas).insert(
              TablaVentasCompanion.insert(numeroFactura: numero),
            ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
