import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/inventario/modelo/movimiento_inventario.dart';
import 'package:inventario_k1/backend/features/inventario/repositorio/repositorio_inventario_impl.dart';
import 'package:inventario_k1/backend/features/pos/enum/enum_ventas.dart';
import 'package:inventario_k1/backend/features/pos/modelo/linea_venta_mostrador.dart';
import 'package:inventario_k1/backend/features/pos/repositorio/repositorio_ventas.dart';
import 'package:inventario_k1/backend/features/pos/repositorio/repositorio_ventas_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/datos_taller.dart';
import 'soporte/sesion_de_prueba.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';

late AppDb db;

/// Quien firma lo que escriben estos tests. Ver `sesionDePrueba`.
late SesionActual sesion;
late RepositorioVentasImpl ventas;
late RepositorioInventarioImpl inventario;
late DatosTaller taller;

Future<double> _stock() async {
  final fila = await db
      .customSelect('SELECT stock_actual AS s FROM productos WHERE id = '
          '${taller.productoId}')
      .getSingle();
  return fila.read<double>('s');
}

/// Registra una venta de mostrador con una línea del producto sembrado.
Future<int> _ventaConProducto({
  double cantidad = 3,
  int precioUnitario = 30000,
}) async {
  final resumen = await ventas.registrarVentaMostrador(
    clienteId: taller.clienteId,
    metodoPago: MetodoPago.efectivo,
    lineas: [
      LineaVentaMostrador(
        productoId: taller.productoId,
        descripcion: 'Pastilla de freno',
        cantidad: cantidad,
        precioUnitario: precioUnitario,
        costoUnitario: 18000,
      ),
    ],
  );
  return resumen.id;
}

void main() {
  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
    ventas = RepositorioVentasImpl(db, sesion);
    inventario = RepositorioInventarioImpl(db, sesion);
    taller = await sembrarTaller(db);
  });

  tearDown(() => db.close());

  group('el SQL crudo del resumen sigue cuadrando con el esquema', () {
    // Este grupo existe por un fallo real: al mover la identidad a `personas`,
    // estas consultas siguieron pidiendo `c.nombres` y compilaron igual —
    // `flutter analyze` no entra en un `customSelect`. Reventaban al abrir la
    // pantalla.
    test('la lista trae el nombre del cliente desde personas', () async {
      await _ventaConProducto();

      final lista = await ventas.observarTodas().first;

      expect(lista, hasLength(1));
      expect(lista.single.clienteNombre, 'Carlos Ramírez');
    });

    test('el detalle trae cabecera y líneas', () async {
      final id = await _ventaConProducto();

      final detalle = await ventas.obtenerDetalle(id);

      expect(detalle.clienteNombre, 'Carlos Ramírez');
      expect(detalle.items, hasLength(1));
      expect(detalle.items.single.descripcion, 'Pastilla de freno');
    });
  });

  group('importes en pesos enteros', () {
    test('el subtotal de la línea y el total de la venta son enteros',
        () async {
      final id = await _ventaConProducto(cantidad: 3);

      final detalle = await ventas.obtenerDetalle(id);

      expect(detalle.items.single.subtotal, 90000);
      expect(detalle.subtotal, 90000);
      expect(detalle.total, 90000);
    });

    test('una cantidad fraccionaria redondea al peso, no lo trunca', () async {
      // 0.5 × 30001 = 15000.5. Redondear da 15001; truncar daría 15000 y el
      // medio peso se perdería en cada línea.
      final id = await _ventaConProducto(cantidad: 0.5, precioUnitario: 30001);

      final detalle = await ventas.obtenerDetalle(id);

      expect(detalle.items.single.subtotal, 15001);
      expect(detalle.total, 15001);
    });
  });

  group('anular, no borrar', () {
    test('la venta queda en ANULADA y el stock vuelve', () async {
      final id = await _ventaConProducto(cantidad: 3);
      expect(await _stock(), 7);

      await ventas.anular(id);

      final detalle = await ventas.obtenerDetalle(id);
      expect(detalle.estadoPago, EstadoPago.anulada);
      expect(await _stock(), 10);
      expect(await ventas.observarTodas().first, hasLength(1));
    });

    test('la devolución queda en el libro mayor, no borra la salida',
        () async {
      final id = await _ventaConProducto(cantidad: 3);
      await ventas.anular(id);

      final movimientos =
          await inventario.observarPorProducto(taller.productoId).first;

      expect(movimientos, hasLength(3)); // inicial + salida + devolución
      expect(await inventario.descuadres(), isEmpty);
    });

    test('anular dos veces no se admite', () async {
      final id = await _ventaConProducto();
      await ventas.anular(id);

      expect(() => ventas.anular(id), throwsA(isA<Exception>()));
    });
  });

  group('las guardas de la base', () {
    test('una venta no se puede borrar', () async {
      final id = await _ventaConProducto();

      expect(
        () => db.customStatement('DELETE FROM ventas WHERE id = $id'),
        throwsA(isA<Exception>()),
      );
    });

    test('una venta anulada no se puede modificar', () async {
      final id = await _ventaConProducto();
      await ventas.anular(id);

      expect(
        () => db.customStatement(
            "UPDATE ventas SET estado_pago = 'PAGADO' WHERE id = $id"),
        throwsA(isA<Exception>()),
      );
    });

    test('a una venta anulada no se le agregan líneas', () async {
      final id = await _ventaConProducto();
      await ventas.anular(id);

      expect(
        () => db.into(db.tablaVentaDetalles).insert(
              TablaVentaDetallesCompanion.insert(
                ventaId: id,
                tipoItem: 'SERVICIO',
                servicioId: Value(taller.servicioId),
                descripcion: 'Sincronización',
                precioUnitario: 50000,
                subtotal: 50000,
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('los CHECK del esquema', () {
    test('un método de pago inventado se rechaza', () async {
      final id = await _ventaConProducto();

      expect(
        () => db.customStatement(
            "UPDATE ventas SET metodo_pago = 'BITCOIN' WHERE id = $id"),
        throwsA(isA<Exception>()),
      );
    });

    test('no se puede cobrar más de lo vendido', () async {
      final id = await _ventaConProducto(cantidad: 1);

      expect(
        () => db.customStatement(
            'UPDATE ventas SET total_pagado = 999999 WHERE id = $id'),
        throwsA(isA<Exception>()),
      );
    });

    test('una línea de producto sin producto_id se rechaza', () async {
      final id = await _ventaConProducto();

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
      final id = await _ventaConProducto();

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

    test('el número de la venta no se repite', () async {
      final id = await _ventaConProducto();
      final numero = (await ventas.obtenerDetalle(id)).numeroFactura;

      expect(
        () => db.into(db.tablaVentas).insert(
              TablaVentasCompanion.insert(
                usuarioId: sesion.usuarioId,
                numeroFactura: numero,
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('la venta de mostrador se registra entera o no se registra', () {
    // Este grupo existe por un fallo real: el punto de venta armaba la venta
    // desde el notifier con la cabecera + una línea por producto + el cobro,
    // cada uno con su transacción. Si una línea fallaba a mitad —el caso
    // común es stock insuficiente— quedaba una venta con su consecutivo
    // quemado, con las líneas anteriores ya descontadas del inventario y sin
    // cobrar, indistinguible de una venta legítima.

    /// Un segundo producto con el stock que se le pida.
    Future<int> otroProducto({required double stock}) async {
      final id = await db.into(db.tablaProducto).insert(
            TablaProductoCompanion.insert(
              sku: 'ACE-1',
              nombre: 'Aceite 20W50',
              precioVenta: const Value(25000),
              precioCompra: const Value(15000),
            ),
          );
      if (stock != 0) {
        await inventario.registrar(
          SolicitudMovimiento.entrada(
            productoId: id,
            cantidad: stock,
            tipo: TipoMovimiento.ajusteInicial,
          ),
        );
      }
      return id;
    }

    test('una línea sin stock no deja nada escrito', () async {
      final segundo = await otroProducto(stock: 1);
      final stockAntes = await _stock();

      await expectLater(
        () => ventas.registrarVentaMostrador(
          metodoPago: MetodoPago.efectivo,
          lineas: [
            LineaVentaMostrador(
              productoId: taller.productoId,
              descripcion: 'Pastilla de freno',
              cantidad: 2,
              precioUnitario: 30000,
            ),
            // Solo hay 1: esta revienta y tiene que arrastrar a la anterior.
            LineaVentaMostrador(
              productoId: segundo,
              descripcion: 'Aceite 20W50',
              cantidad: 5,
              precioUnitario: 25000,
            ),
          ],
        ),
        throwsA(isA<Exception>()),
      );

      expect(await ventas.observarTodas().first, isEmpty,
          reason: 'no puede quedar una venta sin líneas');
      expect(await _stock(), stockAntes,
          reason: 'el descuento de la primera línea tiene que revertirse');

      final movimientos = await db
          .customSelect('SELECT COUNT(*) AS n FROM movimientos_inventario '
              "WHERE tipo = 'SALIDA_VENTA'")
          .getSingle();
      expect(movimientos.read<int>('n'), 0,
          reason: 'ninguna salida de inventario sin venta que la explique');
    });

    test('el error de stock nombra el producto que falta', () async {
      // Con ocho líneas, «Stock insuficiente. Disponible: 2» obligaba a
      // revisarlas a mano para saber cuál era.
      await expectLater(
        () => ventas.registrarVentaMostrador(
          metodoPago: MetodoPago.efectivo,
          lineas: [
            LineaVentaMostrador(
              productoId: taller.productoId,
              descripcion: 'Pastilla de freno',
              cantidad: 99,
              precioUnitario: 30000,
            ),
          ],
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'mensaje',
            contains('Pastilla de freno'),
          ),
        ),
      );
    });

    test('la venta completa queda pagada, con sus líneas y su stock al día',
        () async {
      final segundo = await otroProducto(stock: 4);

      final creada = await ventas.registrarVentaMostrador(
        metodoPago: MetodoPago.efectivo,
        clienteId: taller.clienteId,
        lineas: [
          LineaVentaMostrador(
            productoId: taller.productoId,
            descripcion: 'Pastilla de freno',
            cantidad: 2,
            precioUnitario: 30000,
            costoUnitario: 18000,
          ),
          LineaVentaMostrador(
            productoId: segundo,
            descripcion: 'Aceite 20W50',
            cantidad: 1,
            precioUnitario: 25000,
          ),
        ],
      );

      final detalle = await ventas.obtenerDetalle(creada.id);
      expect(detalle.items, hasLength(2));
      expect(detalle.tipo, TipoVenta.mostrador);
      expect(detalle.estadoPago, EstadoPago.pagado);
      expect(creada.total, 85000);
      expect(await _stock(), 8);
      expect(await inventario.stockReconstruido(segundo), 3);
    });

    test('lo cobrado es lo que dice la base, no lo que mande la vista',
        () async {
      // El total no se recibe por parámetro justamente para que no puedan
      // discrepar: si lo mandara la vista, el CHECK `total_pagado <= total`
      // sería lo único entre un descuadre y la contabilidad.
      final creada = await ventas.registrarVentaMostrador(
        metodoPago: MetodoPago.tarjeta,
        descuento: 5000,
        lineas: [
          LineaVentaMostrador(
            productoId: taller.productoId,
            descripcion: 'Pastilla de freno',
            cantidad: 2,
            precioUnitario: 30000,
          ),
        ],
      );

      final fila = await db
          .customSelect('SELECT total, total_pagado FROM ventas '
              'WHERE id = ${creada.id}')
          .getSingle();
      expect(fila.read<int>('total'), 55000);
      expect(fila.read<int>('total_pagado'), fila.read<int>('total'));
    });

    test('una venta sin líneas no quema un consecutivo', () async {
      await expectLater(
        () => ventas.registrarVentaMostrador(
          metodoPago: MetodoPago.efectivo,
          lineas: const [],
        ),
        throwsA(isA<Exception>()),
      );

      expect(await ventas.observarTodas().first, isEmpty);
    });
  });

  group('el historial pagina y filtra en SQL', () {
    // Es lo que mira la pantalla de Historial de ventas. Lo que se prueba aquí
    // es que el `WHERE`, el `COUNT` y el `LIMIT` los resuelva SQLite: traer
    // todas las facturas para recortarlas en Dart es lo que esta consulta
    // existe para evitar.

    test('el total no lo recorta el LIMIT', () async {
      await _ventaConProducto(cantidad: 1);
      await _ventaConProducto(cantidad: 1);
      await _ventaConProducto(cantidad: 1);

      final pagina = await ventas
          .observarPagina(
            filtro: const FiltroVentas(),
            pagina: 0,
            tamano: 2,
          )
          .first;

      expect(pagina.items, hasLength(2));
      expect(pagina.total, 3);
    });

    test('la suma tampoco: es la del periodo, no la de la página', () async {
      // El pie decía «En esta página: $X» porque eso era lo único que tenía a
      // mano. Con tres ventas de 30.000 y una página de dos, sumar lo visible
      // habría dado 60.000 y el mes se habría reportado corto.
      await _ventaConProducto(cantidad: 1);
      await _ventaConProducto(cantidad: 1);
      await _ventaConProducto(cantidad: 1);

      final pagina = await ventas
          .observarPagina(
            filtro: const FiltroVentas(),
            pagina: 0,
            tamano: 2,
          )
          .first;

      expect(pagina.items, hasLength(2));
      expect(pagina.sumaNeta, 90000);
    });

    test('la suma va neta y sin las anuladas', () async {
      // Lo devuelto salió de la caja y lo anulado nunca entró: es la cifra
      // con la que se cuadra el cajón, no la de lo que se facturó.
      final vivaId = await _ventaConProducto(cantidad: 1);
      final anuladaId = await _ventaConProducto(cantidad: 1);
      await ventas.anular(anuladaId);

      final pagina = await ventas
          .observarPagina(
            filtro: const FiltroVentas(),
            pagina: 0,
            tamano: 10,
          )
          .first;

      expect(pagina.total, 2, reason: 'la anulada sigue en el listado');
      expect(pagina.sumaNeta, 30000);
      expect(
        pagina.items.firstWhere((v) => v.id == vivaId).totalNeto,
        30000,
      );
    });

    test('el filtro recorta la suma, no solo las filas', () async {
      await _ventaConProducto(cantidad: 1);
      await _ventaConProducto(cantidad: 1);

      final futuras = await ventas
          .observarPagina(
            filtro: FiltroVentas(
              desde: DateTime.now().add(const Duration(days: 1)),
            ),
            pagina: 0,
            tamano: 10,
          )
          .first;

      expect(futuras.total, 0);
      expect(futuras.sumaNeta, 0);
    });

    test('cada venta trae el nombre de quien la hizo', () async {
      await _ventaConProducto(cantidad: 1);

      final pagina = await ventas
          .observarPagina(
            filtro: const FiltroVentas(),
            pagina: 0,
            tamano: 10,
          )
          .first;

      // `sesionDePrueba` inserta a «Usuario de prueba».
      expect(pagina.items.single.cajero, 'Usuario de prueba');
    });

    test('filtrar por cajero deja fuera lo de los demás', () async {
      final otra = await sesionDePrueba(db, usuario: 'otro');
      await _ventaConProducto(cantidad: 1);
      await RepositorioVentasImpl(db, otra).registrarVentaMostrador(
        clienteId: taller.clienteId,
        metodoPago: MetodoPago.efectivo,
        lineas: [
          LineaVentaMostrador(
            productoId: taller.productoId,
            descripcion: 'Pastilla de freno',
            cantidad: 1,
            precioUnitario: 30000,
            costoUnitario: 18000,
          ),
        ],
      );

      final suyas = await ventas
          .observarPagina(
            filtro: FiltroVentas(usuarioId: otra.usuarioId),
            pagina: 0,
            tamano: 10,
          )
          .first;

      expect(suyas.total, 1);
      expect(suyas.items.single.cajero, isNotEmpty);
    });

    test('la búsqueda mira el número de factura', () async {
      final id = await _ventaConProducto(cantidad: 1);
      final detalle = await ventas.obtenerDetalle(id);

      final pagina = await ventas
          .observarPagina(
            filtro: FiltroVentas(busqueda: detalle.numeroFactura),
            pagina: 0,
            tamano: 10,
          )
          .first;

      expect(pagina.total, 1);
    });

    test('una venta anulada se puede aislar por estado', () async {
      final id = await _ventaConProducto(cantidad: 1);
      await _ventaConProducto(cantidad: 1);
      await ventas.anular(id);

      final anuladas = await ventas
          .observarPagina(
            filtro: const FiltroVentas(estado: EstadoPago.anulada),
            pagina: 0,
            tamano: 10,
          )
          .first;

      expect(anuladas.total, 1);
      expect(anuladas.items.single.id, id);
    });
  });
}
