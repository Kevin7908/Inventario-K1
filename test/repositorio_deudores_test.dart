import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/deudores/enum/enum_deudor.dart';
import 'package:inventario_k1/backend/features/deudores/repositorio/repositorio_deudores_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/metodo_pago.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/datos_taller.dart';

late AppDb db;
late RepositorioDeudoresImpl deudores;
late DatosTaller taller;

Future<int> _deuda({int monto = 100000, int pagoInicial = 0}) => deudores.crear(
      clienteId: taller.clienteId,
      concepto: 'Repuestos a crédito',
      montoTotal: monto,
      pagoInicial: pagoInicial,
      fechaVencimiento: DateTime.now().add(const Duration(days: 15)),
    );

void main() {
  setUp(() async {
    db = baseEnMemoria();
    deudores = RepositorioDeudoresImpl(db);
    taller = await sembrarTaller(db);
  });

  tearDown(() => db.close());

  group('el monto pagado es la suma de los pagos', () {
    test('cada pago recalcula el caché', () async {
      final id = await _deuda(monto: 100000, pagoInicial: 30000);

      await deudores.registrarPago(
        deudorId: id,
        monto: 20000,
        metodoPago: MetodoPago.nequi,
      );

      final detalle = await deudores.obtenerDetalle(id);
      expect(detalle.resumen.montoPagado, 50000);
      expect(await deudores.descuadres(), isEmpty);
    });

    test('terminar de pagar la cierra sola', () async {
      final id = await _deuda(monto: 40000);

      await deudores.registrarPago(
        deudorId: id,
        monto: 40000,
        metodoPago: MetodoPago.efectivo,
      );

      final detalle = await deudores.obtenerDetalle(id);
      expect(detalle.resumen.estado, EstadoDeudor.pagada);
    });

    test('descuadres delata al que escribe el caché por fuera', () async {
      final id = await _deuda(monto: 100000, pagoInicial: 30000);

      await db.customStatement(
        'UPDATE deudores SET monto_pagado = 45000 WHERE id = $id',
      );

      expect(await deudores.descuadres(), {id: 15000});
    });
  });

  group('los CHECK del esquema', () {
    test('no se puede pagar más de lo debido', () async {
      final id = await _deuda(monto: 50000);

      expect(
        () => db.customStatement(
            'UPDATE deudores SET monto_pagado = 60000 WHERE id = $id'),
        throwsA(isA<Exception>()),
      );
    });

    test('una deuda de cero no tiene sentido', () async {
      expect(
        () => _deuda(monto: 0),
        throwsA(isA<Exception>()),
      );
    });

    test('un estado inventado se rechaza', () async {
      final id = await _deuda();

      expect(
        () => db.customStatement(
            "UPDATE deudores SET estado = 'EN_DISPUTA' WHERE id = $id"),
        throwsA(isA<Exception>()),
      );
    });

    test('un pago con método fuera del enum se rechaza', () async {
      final id = await _deuda();

      expect(
        () => db.into(db.tablaDeudorPago).insert(
              TablaDeudorPagoCompanion.insert(
                deudorId: id,
                monto: 1000,
                metodoPago: 'TRUEQUE',
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('borrar la deuda se lleva sus pagos', () async {
      final id = await _deuda(pagoInicial: 10000);

      await deudores.eliminar(id);

      final pagos = await db
          .customSelect('SELECT COUNT(*) AS n FROM deudor_pagos')
          .getSingle();
      expect(pagos.read<int>('n'), 0);
    });

    test('no se borra a un cliente que debe', () async {
      await _deuda();

      expect(
        () => db.customStatement(
            'DELETE FROM clientes WHERE id = ${taller.clienteId}'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('vencimiento', () {
    test('estaVencida mira el calendario, no el estado guardado', () async {
      final id = await deudores.crear(
        clienteId: taller.clienteId,
        concepto: 'Vencida',
        montoTotal: 10000,
        fechaVencimiento: DateTime.now().subtract(const Duration(days: 1)),
      );

      final detalle = await deudores.obtenerDetalle(id);
      expect(detalle.resumen.estado, EstadoDeudor.activa,
          reason: 'nadie la marcó como vencida');
      expect(detalle.resumen.estaVencida, isTrue);
    });

    test('una deuda pagada no vence aunque pase la fecha', () async {
      final id = await deudores.crear(
        clienteId: taller.clienteId,
        concepto: 'Saldada',
        montoTotal: 10000,
        pagoInicial: 10000,
        fechaVencimiento: DateTime.now().subtract(const Duration(days: 30)),
      );

      final detalle = await deudores.obtenerDetalle(id);
      expect(detalle.resumen.estado, EstadoDeudor.pagada);
      expect(detalle.resumen.estaVencida, isFalse);
    });
  });
}
