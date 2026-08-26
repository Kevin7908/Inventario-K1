import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/devoluciones/enum/enum_devoluciones.dart';
import 'package:inventario_k1/backend/features/devoluciones/modelo/devolucion.dart';
import 'package:inventario_k1/backend/features/devoluciones/repositorio/repositorio_devoluciones_impl.dart';
import 'package:inventario_k1/backend/features/inventario/modelo/movimiento_inventario.dart';
import 'package:inventario_k1/backend/features/inventario/repositorio/repositorio_inventario_impl.dart';
import 'package:inventario_k1/backend/features/pos/enum/enum_ventas.dart';
import 'package:inventario_k1/backend/features/pos/modelo/linea_venta_mostrador.dart';
import 'package:inventario_k1/backend/features/pos/repositorio/repositorio_ventas_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/permiso.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';
import 'package:inventario_k1/core/resultado.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/datos_taller.dart';
import 'soporte/sesion_de_prueba.dart';

late AppDb db;
late SesionActual sesion;
late RepositorioVentasImpl ventas;
late RepositorioDevolucionesImpl devoluciones;
late RepositorioInventarioImpl inventario;
late DatosTaller taller;

Future<double> _stock() async {
  final fila = await db.customSelect(
    'SELECT stock_actual AS s FROM productos WHERE id = ?',
    variables: [Variable.withInt(taller.productoId)],
  ).getSingle();
  return fila.read<double>('s');
}

/// Una venta de mostrador con una sola línea del producto sembrado.
Future<int> _venta({double cantidad = 5, int precio = 30000}) async {
  final resumen = await ventas.registrarVentaMostrador(
    clienteId: taller.clienteId,
    metodoPago: MetodoPago.efectivo,
    lineas: [
      LineaVentaMostrador(
        productoId: taller.productoId,
        descripcion: 'Pastilla de freno',
        cantidad: cantidad,
        precioUnitario: precio,
        costoUnitario: 18000,
      ),
    ],
  );
  return resumen.id;
}

Future<Resultado> _devolver(int ventaId, double cantidad) async {
  final lineas = await devoluciones.lineasDevolvibles(ventaId);
  return devoluciones.registrar(
    ventaId: ventaId,
    motivo: MotivoDevolucion.defectuoso,
    lineas: [
      LineaADevolver(
        ventaDetalleId: lineas.single.ventaDetalleId,
        cantidad: cantidad,
      ),
    ],
  );
}

void main() {
  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
    ventas = RepositorioVentasImpl(db, sesion);
    devoluciones = RepositorioDevolucionesImpl(db, sesion);
    inventario = RepositorioInventarioImpl(db, sesion);
    // 20 en stock: entra como movimiento, igual que en la app.
    taller = await sembrarTaller(db, stockInicial: 20, usuarioId: sesion.usuarioId);
  });

  tearDown(() => db.close());

  group('lo que se puede devolver sale de SQL', () {
    test('una venta sin devoluciones tiene todo disponible', () async {
      final ventaId = await _venta(cantidad: 5);

      final lineas = await devoluciones.lineasDevolvibles(ventaId);

      expect(lineas, hasLength(1));
      expect(lineas.single.cantidadVendida, 5);
      expect(lineas.single.cantidadDevuelta, 0);
      expect(lineas.single.disponible, 5);
      expect(lineas.single.esProducto, isTrue);
    });

    test('lo ya devuelto se descuenta de lo disponible', () async {
      final ventaId = await _venta(cantidad: 5);
      await _devolver(ventaId, 2);

      final lineas = await devoluciones.lineasDevolvibles(ventaId);

      expect(lineas.single.cantidadDevuelta, 2);
      expect(lineas.single.disponible, 3);
    });
  });

  group('devolver repone stock y deja documento', () {
    test('el stock vuelve exactamente por lo devuelto', () async {
      final ventaId = await _venta(cantidad: 5);
      expect(await _stock(), 15);

      expect(await _devolver(ventaId, 2), isA<Exito>());

      expect(await _stock(), 17);
      expect(await inventario.descuadres(), isEmpty);
    });

    test('el movimiento queda como DEVOLUCION_VENTA y apunta a la venta',
        () async {
      final ventaId = await _venta(cantidad: 5);
      await _devolver(ventaId, 2);

      final movimientos =
          await inventario.observarPorProducto(taller.productoId).first;
      final devolucion = movimientos.first;

      expect(devolucion.tipo, TipoMovimiento.devolucionVenta);
      expect(devolucion.cantidad, 2);
      expect(devolucion.ventaId, ventaId);
    });

    test('el total sale del precio al que se vendió, no del catálogo',
        () async {
      final ventaId = await _venta(cantidad: 5, precio: 30000);
      await _devolver(ventaId, 2);

      final documento =
          (await devoluciones.observarPorVenta(ventaId).first).single;

      expect(documento.total, 60000);
      expect(documento.numero, startsWith('DEV-'));
      expect(documento.motivo, MotivoDevolucion.defectuoso);
      expect(documento.lineas.single.descripcion, 'Pastilla de freno');
      expect(documento.recibidoPor, isNotEmpty);
    });

    test('el caché del total cuadra con sus líneas', () async {
      final ventaId = await _venta(cantidad: 5);
      await _devolver(ventaId, 2);
      await _devolver(ventaId, 1);

      expect(await devoluciones.descuadres(), isEmpty);
    });

    test('la venta conserva su total y su estado', () async {
      final ventaId = await _venta(cantidad: 5, precio: 30000);
      await _devolver(ventaId, 2);

      final resumen = (await ventas.observarTodas().first)
          .firstWhere((v) => v.id == ventaId);

      // La factura de ayer dice lo que se cobró ayer.
      expect(resumen.estadoPago, EstadoPago.pagado);
      expect(resumen.total, 150000);
      expect(resumen.totalDevuelto, 60000);
      expect(resumen.totalNeto, 90000);
    });

    test('devolver en dos veces suma hasta lo vendido', () async {
      final ventaId = await _venta(cantidad: 5);

      expect(await _devolver(ventaId, 3), isA<Exito>());
      expect(await _devolver(ventaId, 2), isA<Exito>());

      expect(await _stock(), 20);
      expect((await devoluciones.lineasDevolvibles(ventaId)).single.disponible, 0);
    });
  });

  group('lo que no se puede hacer', () {
    test('no se devuelve más de lo vendido', () async {
      final ventaId = await _venta(cantidad: 5);

      final fallo = await _devolver(ventaId, 6);

      expect(fallo, isA<Fallo>());
      expect((fallo as Fallo).motivo, MotivoFallo.validacion);
      expect(fallo.mensaje, contains('solo quedan 5'));
      // Y no escribió nada.
      expect(await _stock(), 15);
      expect(await devoluciones.observarPorVenta(ventaId).first, isEmpty);
    });

    test('dos devoluciones no se pueden pasar entre las dos', () async {
      final ventaId = await _venta(cantidad: 5);
      await _devolver(ventaId, 4);

      final fallo = await _devolver(ventaId, 2);

      expect(fallo, isA<Fallo>());
      expect(await _stock(), 19);
    });

    test('una devolución sin líneas no se registra', () async {
      final ventaId = await _venta();

      final fallo = await devoluciones.registrar(
        ventaId: ventaId,
        motivo: MotivoDevolucion.garantia,
        lineas: const [],
      );

      expect((fallo as Fallo).motivo, MotivoFallo.validacion);
    });

    test('no se devuelve contra una venta anulada', () async {
      final ventaId = await _venta(cantidad: 5);
      await ventas.anular(ventaId);

      final fallo = await _devolver(ventaId, 1);

      expect(fallo, isA<Fallo>());
      expect((fallo as Fallo).mensaje, contains('anulada'));
    });

    test('la guarda de la base rechaza pasarse aunque nadie valide en Dart',
        () async {
      final ventaId = await _venta(cantidad: 5);
      final linea = (await devoluciones.lineasDevolvibles(ventaId)).single;

      final devolucionId = await db.customSelect(
        'INSERT INTO devoluciones (numero, venta_id, motivo, total, usuario_id) '
        "VALUES ('DEV-9999', ?, 'GARANTIA', 1000, ?) RETURNING id",
        variables: [
          Variable.withInt(ventaId),
          Variable.withInt(sesion.usuarioId),
        ],
      ).getSingle();

      // 9 de una línea de 5: solo la guarda lo impide.
      expect(
        () => db.customStatement(
          'INSERT INTO devolucion_detalles '
          '(devolucion_id, venta_detalle_id, cantidad, precio_unitario) '
          'VALUES (?, ?, 9, 30000)',
          [devolucionId.read<int>('id'), linea.ventaDetalleId],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('una devolución no se borra ni se edita', () async {
      final ventaId = await _venta(cantidad: 5);
      await _devolver(ventaId, 2);
      final documento =
          (await devoluciones.observarPorVenta(ventaId).first).single;

      expect(
        () => db.customStatement(
          'DELETE FROM devoluciones WHERE id = ?',
          [documento.id],
        ),
        throwsA(isA<Exception>()),
      );
      expect(
        () => db.customStatement(
          'UPDATE devoluciones SET total = 1 WHERE id = ?',
          [documento.id],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('sin POS_ANULAR no se puede devolver', () async {
      final ventaId = await _venta(cantidad: 5);
      final cajero = await sesionDePrueba(
        db,
        permisos: {Permiso.posVer, Permiso.posVender},
        usuario: 'cajero',
      );
      final sinPermiso = RepositorioDevolucionesImpl(db, cajero);

      final lineas = await devoluciones.lineasDevolvibles(ventaId);

      expect(
        () => sinPermiso.registrar(
          ventaId: ventaId,
          motivo: MotivoDevolucion.garantia,
          lineas: [
            LineaADevolver(
              ventaDetalleId: lineas.single.ventaDetalleId,
              cantidad: 1,
            ),
          ],
        ),
        throwsA(isA<PermisoDenegado>()),
      );
    });
  });

  group('anular después de devolver no repone dos veces', () {
    // Es el bug que la devolución parcial introduce si nadie lo mira: anular
    // devolvía la cantidad completa de cada línea sin descontar lo que una
    // devolución ya había repuesto.
    test('anular solo repone lo que quedaba por devolver', () async {
      final ventaId = await _venta(cantidad: 5);
      expect(await _stock(), 15);

      await _devolver(ventaId, 2);
      expect(await _stock(), 17);

      await ventas.anular(ventaId);

      // 20, no 22: los 2 ya habían vuelto.
      expect(await _stock(), 20);
      expect(await inventario.descuadres(), isEmpty);
    });

    test('anular una venta devuelta entera no repone nada', () async {
      final ventaId = await _venta(cantidad: 5);
      await _devolver(ventaId, 5);
      expect(await _stock(), 20);

      await ventas.anular(ventaId);

      expect(await _stock(), 20);
      expect(await inventario.descuadres(), isEmpty);
    });
  });
}
