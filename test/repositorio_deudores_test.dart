import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/deudores/enum/enum_deudor.dart';
import 'package:inventario_k1/backend/features/deudores/repositorio/repositorio_deudores.dart';
import 'package:inventario_k1/backend/features/deudores/repositorio/repositorio_deudores_impl.dart';
import 'package:inventario_k1/core/resultado.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/metodo_pago.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/datos_taller.dart';

late AppDb db;
late RepositorioDeudoresImpl deudores;
late DatosTaller taller;

Future<int> _deuda({
  int monto = 100000,
  int pagoInicial = 0,
  String concepto = 'Repuestos a crédito',
  DateTime? vence,
}) =>
    deudores.crear(
      clienteId: taller.clienteId,
      concepto: concepto,
      montoTotal: monto,
      pagoInicial: pagoInicial,
      fechaVencimiento: vence ?? DateTime.now().add(const Duration(days: 15)),
    );

DateTime _haceDias(int dias) =>
    DateTime.now().subtract(Duration(days: dias));

/// Una página del listado, ya resuelta. Los streams de Drift necesitan un
/// oyente para emitir: `.first` lo es.
Future<PaginaDeudores> _pagina({
  FiltroDeudores filtro = const FiltroDeudores(),
  int pagina = 0,
  int tamano = 10,
}) =>
    deudores
        .observarPagina(filtro: filtro, pagina: pagina, tamano: tamano)
        .first;

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

  group('el listado se recorta en SQL, no en memoria', () {
    test('la página trae su tramo y el total cuenta todas', () async {
      for (var i = 0; i < 7; i++) {
        await _deuda(concepto: 'Deuda $i');
      }

      final primera = await _pagina(tamano: 3);
      final tercera = await _pagina(pagina: 2, tamano: 3);

      expect(primera.items, hasLength(3));
      expect(tercera.items, hasLength(1));
      // El total ignora el LIMIT: es cuántas hay, no cuántas caben.
      expect(primera.total, 7);
      expect(tercera.total, 7);
    });

    test('la búsqueda mira número, concepto y nombre del cliente', () async {
      await _deuda(concepto: 'Kit de arrastre');
      await _deuda(concepto: 'Aceite y filtro');

      final porConcepto = await _pagina(
        filtro: const FiltroDeudores(busqueda: 'arrastre'),
      );
      final porCliente = await _pagina(
        filtro: const FiltroDeudores(busqueda: 'ramírez'),
      );
      final sinCoincidencia = await _pagina(
        filtro: const FiltroDeudores(busqueda: 'llanta'),
      );

      expect(porConcepto.total, 1);
      expect(porConcepto.items.single.concepto, 'Kit de arrastre');
      expect(porCliente.total, 2, reason: 'las dos son del mismo cliente');
      expect(sinCoincidencia.items, isEmpty);
      expect(sinCoincidencia.total, 0);
    });

    test('«vencidas» son las del plazo cumplido, no las marcadas', () async {
      final vencida = await _deuda(concepto: 'Vieja', vence: _haceDias(3));
      await _deuda(concepto: 'Al día');

      final tramo =
          await _pagina(filtro: const FiltroDeudores(vista: VistaDeudores.vencidas));

      expect(tramo.items.map((d) => d.id), [vencida]);
      expect(tramo.items.single.estado, EstadoDeudor.activa,
          reason: 'nadie la marcó: la venció el calendario');
    });

    test('una deuda sin plazo nunca cae en «vencidas»', () async {
      final id = await deudores.crear(
        clienteId: taller.clienteId,
        concepto: 'Sin plazo pactado',
        montoTotal: 50000,
      );

      final vencidas =
          await _pagina(filtro: const FiltroDeudores(vista: VistaDeudores.vencidas));
      final alDia =
          await _pagina(filtro: const FiltroDeudores(vista: VistaDeudores.alDia));

      expect(vencidas.items, isEmpty);
      expect(alDia.items.map((d) => d.id), [id]);
    });

    test('una deuda cobrada sale de las vivas y entra en «pagadas»', () async {
      final id = await _deuda(monto: 40000, vence: _haceDias(10));

      await deudores.registrarPago(
        deudorId: id,
        monto: 40000,
        metodoPago: MetodoPago.efectivo,
      );

      final vencidas =
          await _pagina(filtro: const FiltroDeudores(vista: VistaDeudores.vencidas));
      final pagadas =
          await _pagina(filtro: const FiltroDeudores(vista: VistaDeudores.pagadas));

      expect(vencidas.items, isEmpty,
          reason: 'ya se cobró: el plazo dejó de importar');
      expect(pagadas.items.map((d) => d.id), [id]);
    });

    test('el filtro se aplica igual a la página y al total', () async {
      for (var i = 0; i < 4; i++) {
        await _deuda(concepto: 'Vencida $i', vence: _haceDias(2));
      }
      await _deuda(concepto: 'Al día');

      final tramo = await _pagina(
        filtro: const FiltroDeudores(vista: VistaDeudores.vencidas),
        tamano: 2,
      );

      expect(tramo.items, hasLength(2));
      expect(tramo.total, 4, reason: 'la de al día no cuenta ni en el total');
    });
  });

  group('los contadores de la cabecera salen de un COUNT/SUM', () {
    test('reparte la cartera entre al día, vencidas y pagadas', () async {
      await _deuda(monto: 100000, pagoInicial: 30000); // al día, saldo 70.000
      await _deuda(monto: 50000, vence: _haceDias(5)); // vencida, saldo 50.000
      final saldada = await _deuda(monto: 20000);
      await deudores.registrarPago(
        deudorId: saldada,
        monto: 20000,
        metodoPago: MetodoPago.efectivo,
      );

      final resumen = await deudores.observarResumen().first;

      expect(resumen.alDia, 1);
      expect(resumen.vencidas, 1);
      expect(resumen.pagadas, 1);
      // Solo la plata que sigue viva: la saldada no suma.
      expect(resumen.porCobrar, 120000);
    });

    test('una deuda incobrable deja de contarse como por cobrar', () async {
      final id = await _deuda(monto: 80000);

      await deudores.cambiarEstado(id, EstadoDeudor.incobrable);
      final resumen = await deudores.observarResumen().first;

      expect(resumen.porCobrar, 0);
      expect(resumen.alDia, 0);
      expect(resumen.vencidas, 0);
    });

    test('sin cartera los cuatro números son cero, no null', () async {
      final resumen = await deudores.observarResumen().first;

      expect(resumen.porCobrar, 0);
      expect(resumen.alDia, 0);
      expect(resumen.vencidas, 0);
      expect(resumen.pagadas, 0);
    });
  });

  group('las escrituras devuelven un fallo tipado, no una excepción', () {
    test('cobrar más del saldo se rechaza con el saldo en el mensaje',
        () async {
      final id = await _deuda(monto: 60000, pagoInicial: 40000);

      final resultado = await deudores.registrarPago(
        deudorId: id,
        monto: 25000,
        metodoPago: MetodoPago.efectivo,
      );

      expect(resultado, isA<Fallo>());
      expect((resultado as Fallo).motivo, MotivoFallo.validacion);
      expect(resultado.mensaje, contains('20000'));
      // Y no queda escrito nada.
      final detalle = await deudores.obtenerDetalle(id);
      expect(detalle.resumen.montoPagado, 40000);
      expect(detalle.pagos, hasLength(1));
    });

    test('bajar el monto por debajo de lo cobrado se rechaza', () async {
      final id = await _deuda(monto: 100000, pagoInicial: 60000);

      final resultado = await deudores.actualizar(
        id: id,
        concepto: 'Rebajada',
        montoTotal: 30000,
      );

      expect(resultado, isA<Fallo>());
      final detalle = await deudores.obtenerDetalle(id);
      expect(detalle.resumen.montoTotal, 100000);
      expect(detalle.resumen.concepto, 'Repuestos a crédito');
    });

    test('subir el monto reabre la deuda que estaba saldada', () async {
      final id = await _deuda(monto: 40000, pagoInicial: 40000);
      expect((await deudores.obtenerDetalle(id)).resumen.estado,
          EstadoDeudor.pagada);

      final resultado = await deudores.actualizar(
        id: id,
        concepto: 'Se le agregó el kit',
        montoTotal: 90000,
      );

      expect(resultado, isA<Exito>());
      final detalle = await deudores.obtenerDetalle(id);
      expect(detalle.resumen.estado, EstadoDeudor.activa);
      expect(detalle.resumen.saldo, 50000);
      expect(await deudores.descuadres(), isEmpty);
    });

    test('no se puede dar por pagada una deuda con saldo', () async {
      final id = await _deuda(monto: 100000, pagoInicial: 10000);

      final resultado = await deudores.cambiarEstado(id, EstadoDeudor.pagada);

      expect(resultado, isA<Fallo>());
      // Es justo lo que descuadraría el caché contra la suma de los pagos.
      expect(await deudores.descuadres(), isEmpty);
      expect((await deudores.obtenerDetalle(id)).resumen.estado,
          EstadoDeudor.activa);
    });

    test('borrar el último pago devuelve la deuda a activa', () async {
      final id = await _deuda(monto: 30000, pagoInicial: 30000);
      final detalle = await deudores.obtenerDetalle(id);
      expect(detalle.resumen.estado, EstadoDeudor.pagada);

      final resultado =
          await deudores.eliminarPago(detalle.pagos.single.id, id);

      expect(resultado, isA<Exito>());
      final tras = await deudores.obtenerDetalle(id);
      expect(tras.resumen.estado, EstadoDeudor.activa);
      expect(tras.resumen.montoPagado, 0);
      expect(await deudores.descuadres(), isEmpty);
    });
  });
}
