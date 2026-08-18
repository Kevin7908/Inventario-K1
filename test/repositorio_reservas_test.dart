import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/inventario/repositorio/repositorio_inventario_impl.dart';
import 'package:inventario_k1/backend/features/reservas/enum/enum_reserva.dart';
import 'package:inventario_k1/backend/features/reservas/repositorio/repositorio_reservas.dart';
import 'package:inventario_k1/backend/features/reservas/repositorio/repositorio_reservas_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/metodo_pago.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/datos_taller.dart';

late AppDb db;
late RepositorioReservasImpl reservas;
late RepositorioInventarioImpl inventario;
late DatosTaller taller;

Future<double> _stock() async {
  final fila = await db
      .customSelect('SELECT stock_actual AS s FROM productos WHERE id = '
          '${taller.productoId}')
      .getSingle();
  return fila.read<double>('s');
}

Future<int> _reserva({
  int total = 100000,
  int abonoInicial = 0,
  double cantidad = 2,
}) =>
    reservas.crear(
      clienteId: taller.clienteId,
      fechaLimite: DateTime.now().add(const Duration(days: 30)),
      totalReserva: total,
      abonoInicial: abonoInicial,
      items: [
        ItemReservaDraft(
          productoId: taller.productoId,
          cantidad: cantidad,
          precioUnitario: 30000,
        ),
      ],
    );

void main() {
  setUp(() async {
    db = baseEnMemoria();
    reservas = RepositorioReservasImpl(db);
    inventario = RepositorioInventarioImpl(db);
    taller = await sembrarTaller(db);
  });

  tearDown(() => db.close());

  group('apartar mueve el inventario por el libro mayor', () {
    test('reservar descuenta y deja su movimiento', () async {
      final id = await _reserva(cantidad: 3);

      expect(await _stock(), 7);
      final movimientos =
          await inventario.observarPorProducto(taller.productoId).first;
      expect(movimientos.first.reservaId, id);
      expect(await inventario.descuadres(), isEmpty);
    });

    test('cancelarla devuelve la mercancía', () async {
      final id = await _reserva(cantidad: 3);

      await reservas.cambiarEstado(id, EstadoReserva.cancelada);

      expect(await _stock(), 10);
      expect(await inventario.descuadres(), isEmpty);
    });
  });

  group('el pagado acumulado es la suma de los abonos', () {
    test('el abono inicial entra como abono, no como columna suelta',
        () async {
      final id = await _reserva(total: 100000, abonoInicial: 40000);

      final detalle = await reservas.obtenerDetalle(id);
      expect(detalle.abonos, hasLength(1));
      expect(detalle.resumen.pagadoAcumulado, 40000);
      expect(await reservas.descuadres(), isEmpty);
    });

    test('cada abono nuevo recalcula el caché', () async {
      final id = await _reserva(total: 100000, abonoInicial: 40000);

      await reservas.registrarAbono(
        reservaId: id,
        monto: 25000,
        metodoPago: MetodoPago.nequi,
      );

      final detalle = await reservas.obtenerDetalle(id);
      expect(detalle.resumen.pagadoAcumulado, 65000);
      expect(detalle.resumen.saldo, 35000);
      expect(await reservas.descuadres(), isEmpty);
    });

    test('terminar de pagar la cierra sola', () async {
      final id = await _reserva(total: 60000);

      await reservas.registrarAbono(
        reservaId: id,
        monto: 60000,
        metodoPago: MetodoPago.efectivo,
      );

      final detalle = await reservas.obtenerDetalle(id);
      expect(detalle.resumen.estado, EstadoReserva.completada);
    });

    test('descuadres delata al que escribe el caché por fuera', () async {
      final id = await _reserva(total: 100000, abonoInicial: 40000);

      await db.customStatement(
        'UPDATE reservas SET pagado_acumulado = 50000 WHERE id = $id',
      );

      expect(await reservas.descuadres(), {id: 10000});
    });
  });

  group('los CHECK del esquema', () {
    test('no se puede recibir más de lo pactado', () async {
      final id = await _reserva(total: 50000);

      expect(
        () => db.customStatement(
            'UPDATE reservas SET pagado_acumulado = 60000 WHERE id = $id'),
        throwsA(isA<Exception>()),
      );
    });

    test('un estado inventado se rechaza', () async {
      final id = await _reserva();

      expect(
        () => db.customStatement(
            "UPDATE reservas SET estado = 'EN_ESPERA' WHERE id = $id"),
        throwsA(isA<Exception>()),
      );
    });

    test('un abono de cero no se admite', () async {
      final id = await _reserva();

      expect(
        () => db.into(db.tablaReservaAbono).insert(
              TablaReservaAbonoCompanion.insert(
                reservaId: id,
                monto: 0,
                metodoPago: 'EFECTIVO',
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('un método de pago fuera del enum se rechaza', () async {
      final id = await _reserva();

      expect(
        () => db.into(db.tablaReservaAbono).insert(
              TablaReservaAbonoCompanion.insert(
                reservaId: id,
                monto: 1000,
                metodoPago: 'BITCOIN',
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('CREDITO no es una forma de abonar', () async {
      // Aplazar el pago es una condición de factura, no dinero entregado.
      final id = await _reserva();

      expect(
        () => db.into(db.tablaReservaAbono).insert(
              TablaReservaAbonoCompanion.insert(
                reservaId: id,
                monto: 1000,
                metodoPago: MetodoPago.credito.codigo,
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('no se borra un producto apartado', () async {
      await _reserva();

      expect(
        () => db.customStatement(
            'DELETE FROM productos WHERE id = ${taller.productoId}'),
        throwsA(isA<Exception>()),
      );
    });

    test('borrar la cotización deja la reserva sin origen, no la borra',
        () async {
      // `setNull` frente a `cascade`: la cotización es una referencia
      // informativa, así que su desaparición no puede llevarse la reserva.
      final cotizacionId = await db.into(db.tablaCotizacion).insert(
            TablaCotizacionCompanion.insert(
              numero: 'COT-0001',
              vigenciaHasta: DateTime.now(),
            ),
          );
      final id = await reservas.crear(
        clienteId: taller.clienteId,
        cotizacionId: cotizacionId,
        fechaLimite: DateTime.now().add(const Duration(days: 30)),
        totalReserva: 50000,
        items: [
          ItemReservaDraft(
            productoId: taller.productoId,
            cantidad: 1,
            precioUnitario: 30000,
          ),
        ],
      );

      await db.customStatement(
          'DELETE FROM cotizaciones WHERE id = $cotizacionId');

      final fila = await db
          .customSelect('SELECT cotizacion_id AS c FROM reservas '
              'WHERE id = $id')
          .getSingle();
      expect(fila.read<int?>('c'), isNull);
    });

    test('borrar la reserva se lleva sus líneas y sus abonos', () async {
      final id = await _reserva(abonoInicial: 10000);

      await reservas.eliminar(id);

      final abonos = await db
          .customSelect('SELECT COUNT(*) AS n FROM reserva_abonos')
          .getSingle();
      final items = await db
          .customSelect('SELECT COUNT(*) AS n FROM reserva_items')
          .getSingle();

      expect(abonos.read<int>('n'), 0);
      expect(items.read<int>('n'), 0);
    });
  });

  group('el método de pago es uno solo en todo el sistema', () {
    test('se guarda en mayúsculas y se lee de vuelta como enum', () async {
      final id = await _reserva();
      await reservas.registrarAbono(
        reservaId: id,
        monto: 1000,
        metodoPago: MetodoPago.daviplata,
      );

      final fila = await db
          .customSelect('SELECT metodo_pago AS m FROM reserva_abonos '
              'WHERE reserva_id = $id')
          .getSingle();
      expect(fila.read<String>('m'), 'DAVIPLATA');

      final detalle = await reservas.obtenerDetalle(id);
      expect(detalle.abonos.single.metodoPago, MetodoPago.daviplata);
    });
  });
}
