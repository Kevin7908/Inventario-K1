// Cuentas por cobrar: lo que se fía sale del inventario y no vuelve solo.
//
// Es lo que separa una deuda de una reserva y donde está el riesgo real del
// módulo: apartar deja el repuesto en la bodega —cancelar lo devuelve—, fiar
// lo saca montado en una moto. Si dar una deuda por perdida devolviera stock,
// el taller creería tener piezas que ya no están.
import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/deudores/enum/enum_deudor.dart';
import 'package:inventario_k1/backend/features/deudores/repositorio/repositorio_deudores.dart';
import 'package:inventario_k1/backend/features/deudores/repositorio/repositorio_deudores_impl.dart';
import 'package:inventario_k1/backend/features/inventario/repositorio/repositorio_inventario_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/metodo_pago.dart';
import 'package:inventario_k1/core/resultado.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/datos_taller.dart';
import 'soporte/sesion_de_prueba.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';

late AppDb db;

/// Quien firma lo que escriben estos tests. Ver `sesionDePrueba`.
late SesionActual sesion;
late RepositorioDeudoresImpl deudores;
late RepositorioInventarioImpl inventario;
late DatosTaller taller;

/// Una deuda vacía, como la que abre el diálogo de «Nueva deuda».
Future<int> _deuda({String? concepto, DateTime? vence}) => deudores.crear(
      clienteId: taller.clienteId,
      motoId: taller.motoId,
      concepto: concepto,
      fechaVencimiento: vence ?? DateTime.now().add(const Duration(days: 15)),
    );

/// Una deuda con una línea ya anotada. [cantidad] × 30.000 es el total.
Future<int> _deudaCon({
  double cantidad = 2,
  int precio = 30000,
  String? concepto,
  DateTime? vence,
}) async {
  final id = await _deuda(concepto: concepto, vence: vence);
  final r = await deudores.agregarItem(
    deudorId: id,
    productoId: taller.productoId,
    cantidad: cantidad,
    precioUnitario: precio,
  );
  expect(r, isA<Exito>(), reason: 'la línea de partida tiene que entrar');
  return id;
}

Future<double> _stock() async {
  final fila = await db
      .customSelect('SELECT stock_actual AS s FROM productos WHERE id = ?',
          variables: [Variable.withInt(taller.productoId)])
      .getSingle();
  return fila.read<double>('s');
}

/// Cuántos renglones dejó la deuda en el libro mayor, por tipo.
Future<Map<String, int>> _movimientos(int deudorId) async {
  final filas = await db.customSelect(
    'SELECT tipo, COUNT(*) AS n FROM movimientos_inventario '
    'WHERE deudor_id = ? GROUP BY tipo',
    variables: [Variable.withInt(deudorId)],
  ).get();
  return {
    for (final f in filas) f.read<String>('tipo'): f.read<int>('n'),
  };
}

DateTime _haceDias(int dias) => DateTime.now().subtract(Duration(days: dias));

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
    sesion = await sesionDePrueba(db);
    deudores = RepositorioDeudoresImpl(db, sesion);
    inventario = RepositorioInventarioImpl(db, sesion);
    taller = await sembrarTaller(db, stockInicial: 10);
  });

  tearDown(() => db.close());

  group('fiar saca la mercancía del taller', () {
    test('anotar una línea descuenta el stock y deja su movimiento', () async {
      final id = await _deudaCon(cantidad: 3);

      expect(await _stock(), 7);
      expect(await _movimientos(id), {'SALIDA_FIADO': 1});
      expect(await inventario.descuadres(), isEmpty);
    });

    test('el total de la deuda es la suma de sus líneas', () async {
      final id = await _deudaCon(cantidad: 2, precio: 30000);

      final detalle = await deudores.obtenerDetalle(id);
      expect(detalle.resumen.montoTotal, 60000);
      expect(detalle.items.single.subtotal, 60000);
      expect(await deudores.descuadresTotal(), isEmpty);
    });

    test('el mismo producto suma a su línea, no abre otra', () async {
      final id = await _deudaCon(cantidad: 2);
      await deudores.agregarItem(
        deudorId: id,
        productoId: taller.productoId,
        cantidad: 1,
        precioUnitario: 30000,
      );

      final detalle = await deudores.obtenerDetalle(id);
      expect(detalle.items, hasLength(1));
      expect(detalle.items.single.cantidad, 3);
      expect(detalle.resumen.montoTotal, 90000);
      expect(await _stock(), 7, reason: 'salieron 3 en total');
    });

    test('no se fía lo que no hay, y no queda nada escrito', () async {
      final id = await _deuda();

      final resultado = await deudores.agregarItem(
        deudorId: id,
        productoId: taller.productoId,
        cantidad: 25,
        precioUnitario: 30000,
      );

      expect(resultado, isA<Fallo>());
      expect((resultado as Fallo).mensaje, contains('No hay stock'));
      expect(await _stock(), 10);
      expect((await deudores.obtenerDetalle(id)).items, isEmpty);
      expect(await _movimientos(id), isEmpty);
    });

    test('subir la cantidad mueve solo la diferencia', () async {
      final id = await _deudaCon(cantidad: 2);
      final item = (await deudores.obtenerDetalle(id)).items.single;

      await deudores.actualizarItem(item.id, cantidad: 5);

      expect(await _stock(), 5, reason: '10 − 2 − 3 más');
      expect(await _movimientos(id), {'SALIDA_FIADO': 2});
      expect((await deudores.obtenerDetalle(id)).resumen.montoTotal, 150000);
    });

    test('bajar la cantidad devuelve solo la diferencia', () async {
      final id = await _deudaCon(cantidad: 5);
      final item = (await deudores.obtenerDetalle(id)).items.single;

      await deudores.actualizarItem(item.id, cantidad: 2);

      expect(await _stock(), 8);
      expect(await _movimientos(id),
          {'SALIDA_FIADO': 1, 'DEVOLUCION_FIADO': 1});
      expect(await inventario.descuadres(), isEmpty);
    });

    test('quitar una línea la corrige: el repuesto vuelve al estante',
        () async {
      // Quitar no es que el cliente devolviera nada: es que la línea nunca
      // debió anotarse.
      final id = await _deudaCon(cantidad: 4);
      final item = (await deudores.obtenerDetalle(id)).items.single;

      await deudores.eliminarItem(item.id);

      expect(await _stock(), 10);
      expect((await deudores.obtenerDetalle(id)).resumen.montoTotal, 0);
      expect(await deudores.descuadresTotal(), isEmpty);
    });
  });

  group('dar por perdida NO devuelve nada al inventario', () {
    test('la deuda se cierra y el stock se queda como está', () async {
      // Es la diferencia de fondo con cancelar una reserva. Si esto devolviera
      // stock, el taller creería tener piezas que se fueron en una moto.
      final id = await _deudaCon(cantidad: 3);
      expect(await _stock(), 7);

      final resultado =
          await deudores.cambiarEstado(id, EstadoDeudor.incobrable);

      expect(resultado, isA<Exito>());
      expect(await _stock(), 7);
      expect(await _movimientos(id), {'SALIDA_FIADO': 1});
    });

    test('una deuda perdida ya no admite líneas', () async {
      final id = await _deudaCon(cantidad: 1);
      await deudores.cambiarEstado(id, EstadoDeudor.incobrable);

      final resultado = await deudores.agregarItem(
        deudorId: id,
        productoId: taller.productoId,
        cantidad: 1,
        precioUnitario: 30000,
      );

      expect(resultado, isA<Fallo>());
      expect(await _stock(), 9, reason: 'solo salió la primera');
    });

    test('una deuda pagada tampoco', () async {
      final id = await _deudaCon(cantidad: 1, precio: 30000);
      await deudores.registrarPago(
        deudorId: id,
        monto: 30000,
        metodoPago: MetodoPago.efectivo,
      );
      expect((await deudores.obtenerDetalle(id)).resumen.estado,
          EstadoDeudor.pagada);

      final resultado = await deudores.agregarItem(
        deudorId: id,
        productoId: taller.productoId,
        cantidad: 1,
        precioUnitario: 30000,
      );

      expect(resultado, isA<Fallo>());
    });

    test('borrar la deuda sí devuelve: es decir que nunca existió', () async {
      final id = await _deudaCon(cantidad: 3);

      await deudores.eliminar(id);

      expect(await _stock(), 10);
      expect(await inventario.descuadres(), isEmpty);
    });
  });

  group('el monto pagado es la suma de los pagos', () {
    test('cada pago recalcula el caché', () async {
      final id = await _deudaCon(cantidad: 3, precio: 30000); // 90.000

      await deudores.registrarPago(
        deudorId: id,
        monto: 30000,
        metodoPago: MetodoPago.nequi,
      );
      await deudores.registrarPago(
        deudorId: id,
        monto: 20000,
        metodoPago: MetodoPago.efectivo,
      );

      final detalle = await deudores.obtenerDetalle(id);
      expect(detalle.resumen.montoPagado, 50000);
      expect(detalle.resumen.saldo, 40000);
      expect(await deudores.descuadres(), isEmpty);
    });

    test('terminar de pagar la cierra sola', () async {
      final id = await _deudaCon(cantidad: 1, precio: 40000);

      await deudores.registrarPago(
        deudorId: id,
        monto: 40000,
        metodoPago: MetodoPago.efectivo,
      );

      expect((await deudores.obtenerDetalle(id)).resumen.estado,
          EstadoDeudor.pagada);
    });

    test('descuadres delata al que escribe el caché por fuera', () async {
      final id = await _deudaCon(cantidad: 3, precio: 30000);
      await deudores.registrarPago(
        deudorId: id,
        monto: 30000,
        metodoPago: MetodoPago.efectivo,
      );

      await db.customStatement(
        'UPDATE deudores SET monto_pagado = 45000 WHERE id = $id',
      );

      expect(await deudores.descuadres(), {id: 15000});
    });

    test('bajar una línea por debajo de lo abonado devuelve la diferencia',
        () async {
      // El cliente entregó más de lo que resultó deber —se le quitó un
      // repuesto que no era—. La plata que sobra se regresa como un pago
      // negativo, no corrigiendo los pagos viejos.
      final id = await _deudaCon(cantidad: 3, precio: 30000); // 90.000
      await deudores.registrarPago(
        deudorId: id,
        monto: 60000,
        metodoPago: MetodoPago.efectivo,
      );
      final item = (await deudores.obtenerDetalle(id)).items.single;

      await deudores.actualizarItem(item.id, cantidad: 1); // baja a 30.000

      final detalle = await deudores.obtenerDetalle(id);
      expect(detalle.resumen.montoTotal, 30000);
      expect(detalle.resumen.montoPagado, 30000);
      expect(detalle.pagos, hasLength(2));
      expect(detalle.pagos.last.monto, -30000, reason: 'la devolución');
      expect(detalle.resumen.estado, EstadoDeudor.pagada,
          reason: 'lo que quedó debiendo ya estaba cubierto');
      expect(await deudores.descuadres(), isEmpty);
      expect(await deudores.descuadresTotal(), isEmpty);
    });
  });

  group('los CHECK del esquema', () {
    test('no se puede pagar más de lo debido', () async {
      final id = await _deudaCon(cantidad: 1, precio: 50000);

      expect(
        () => db.customStatement(
            'UPDATE deudores SET monto_pagado = 60000 WHERE id = $id'),
        throwsA(isA<Exception>()),
      );
    });

    test('un concepto en blanco se rechaza; ninguno se admite', () async {
      final sinConcepto = await deudores.crear(clienteId: taller.clienteId);
      expect((await deudores.obtenerDetalle(sinConcepto)).resumen.concepto,
          isNull);

      expect(
        () => db.customStatement(
            "UPDATE deudores SET concepto = '   ' WHERE id = $sinConcepto"),
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

    test('una línea de cantidad cero no tiene sentido', () async {
      final id = await _deuda();

      expect(
        () => db.into(db.tablaDeudorItem).insert(
              TablaDeudorItemCompanion.insert(
                usuarioId: sesion.usuarioId,
                deudorId: id,
                productoId: Value(taller.productoId),
                descripcion: 'Pastilla de freno',
                cantidad: 0,
                precioUnitario: 30000,
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('una línea sin descripción se rechaza', () async {
      // La descripción es lo único que siempre está: el producto falta en la
      // mano de obra de una orden fiada.
      final id = await _deuda();

      expect(
        () => db.into(db.tablaDeudorItem).insert(
              TablaDeudorItemCompanion.insert(
                usuarioId: sesion.usuarioId,
                deudorId: id,
                descripcion: '   ',
                cantidad: 1,
                precioUnitario: 30000,
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('el mismo producto se suma a su línea, no abre otra', () async {
      // La regla ya no la sostiene un UNIQUE —una orden fiada puede traer el
      // mismo repuesto dos veces a precios distintos—, así que la sostiene el
      // repositorio y por eso se prueba aquí.
      final id = await _deudaCon(cantidad: 1, precio: 30000);

      await deudores.agregarItem(
        deudorId: id,
        productoId: taller.productoId,
        cantidad: 2,
        precioUnitario: 30000,
      );

      final detalle = await deudores.obtenerDetalle(id);
      expect(detalle.items, hasLength(1));
      expect(detalle.items.single.cantidad, 3);
      expect(detalle.resumen.montoTotal, 90000);
    });

    test('un pago con método fuera del enum se rechaza', () async {
      final id = await _deuda();

      expect(
        () => db.into(db.tablaDeudorPago).insert(
              TablaDeudorPagoCompanion.insert(
                usuarioId: sesion.usuarioId,
                deudorId: id,
                monto: 1000,
                metodoPago: 'TRUEQUE',
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('borrar la deuda se lleva sus líneas y sus pagos', () async {
      final id = await _deudaCon(cantidad: 1, precio: 10000);
      await deudores.registrarPago(
        deudorId: id,
        monto: 10000,
        metodoPago: MetodoPago.efectivo,
      );

      await deudores.eliminar(id);

      final quedan = await db
          .customSelect('SELECT '
              '(SELECT COUNT(*) FROM deudor_items) AS i, '
              '(SELECT COUNT(*) FROM deudor_pagos) AS p')
          .getSingle();
      expect(quedan.read<int>('i'), 0);
      expect(quedan.read<int>('p'), 0);
    });

    test('no se borra a un cliente que debe', () async {
      await _deuda();

      expect(
        () => db.customStatement(
            'DELETE FROM clientes WHERE id = ${taller.clienteId}'),
        throwsA(isA<Exception>()),
      );
    });

    test('no se borra un producto que alguien debe', () async {
      await _deudaCon(cantidad: 1);

      expect(
        () => db.customStatement(
            'DELETE FROM productos WHERE id = ${taller.productoId}'),
        throwsA(isA<Exception>()),
      );
    });

    test('borrar la moto deja la deuda en pie, sin moto', () async {
      final id = await _deuda();

      await db.customStatement('DELETE FROM motos WHERE id = ${taller.motoId}');

      final resumen = (await deudores.obtenerDetalle(id)).resumen;
      expect(resumen.motoId, isNull);
      expect(resumen.descripcionMoto, isNull);
    });
  });

  group('vencimiento', () {
    test('estaVencida mira el calendario, no el estado guardado', () async {
      final id = await _deuda(concepto: 'Vencida', vence: _haceDias(1));

      final detalle = await deudores.obtenerDetalle(id);
      expect(detalle.resumen.estado, EstadoDeudor.activa,
          reason: 'nadie la marcó como vencida');
      expect(detalle.resumen.estaVencida, isTrue);
    });

    test('una deuda pagada no vence aunque pase la fecha', () async {
      final id = await _deudaCon(
          cantidad: 1, precio: 10000, vence: _haceDias(30));
      await deudores.registrarPago(
        deudorId: id,
        monto: 10000,
        metodoPago: MetodoPago.efectivo,
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

    test('la cabecera trae la moto en la que se montó lo fiado', () async {
      await _deuda();

      final tramo = await _pagina();

      expect(tramo.items.single.descripcionMoto, 'Bajaj Pulsar · KMN12C');
    });

    test('«vencidas» son las del plazo cumplido, no las marcadas', () async {
      final vencida = await _deuda(concepto: 'Vieja', vence: _haceDias(3));
      await _deuda(concepto: 'Al día');

      final tramo = await _pagina(
          filtro: const FiltroDeudores(vista: VistaDeudores.vencidas));

      expect(tramo.items.map((d) => d.id), [vencida]);
      expect(tramo.items.single.estado, EstadoDeudor.activa,
          reason: 'nadie la marcó: la venció el calendario');
    });

    test('una deuda sin plazo nunca cae en «vencidas»', () async {
      final id = await deudores.crear(
        clienteId: taller.clienteId,
        concepto: 'Sin plazo pactado',
      );

      final vencidas = await _pagina(
          filtro: const FiltroDeudores(vista: VistaDeudores.vencidas));
      final alDia = await _pagina(
          filtro: const FiltroDeudores(vista: VistaDeudores.alDia));

      expect(vencidas.items, isEmpty);
      expect(alDia.items.map((d) => d.id), [id]);
    });

    test('una deuda cobrada sale de las vivas y entra en «pagadas»', () async {
      final id = await _deudaCon(
          cantidad: 1, precio: 40000, vence: _haceDias(10));
      await deudores.registrarPago(
        deudorId: id,
        monto: 40000,
        metodoPago: MetodoPago.efectivo,
      );

      final vencidas = await _pagina(
          filtro: const FiltroDeudores(vista: VistaDeudores.vencidas));
      final pagadas = await _pagina(
          filtro: const FiltroDeudores(vista: VistaDeudores.pagadas));

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
      // Al día: debe 60.000, abonó 30.000 → saldo 30.000
      final alDia = await _deudaCon(cantidad: 2, precio: 30000);
      await deudores.registrarPago(
        deudorId: alDia,
        monto: 30000,
        metodoPago: MetodoPago.efectivo,
      );
      // Vencida: debe 50.000, sin abonos
      await _deudaCon(cantidad: 1, precio: 50000, vence: _haceDias(5));
      // Saldada
      final saldada = await _deudaCon(cantidad: 1, precio: 20000);
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
      expect(resumen.porCobrar, 80000);
    });

    test('una deuda incobrable deja de contarse como por cobrar', () async {
      final id = await _deudaCon(cantidad: 2, precio: 40000);

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
      final id = await _deudaCon(cantidad: 2, precio: 30000); // 60.000
      await deudores.registrarPago(
        deudorId: id,
        monto: 40000,
        metodoPago: MetodoPago.efectivo,
      );

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

    test('a una deuda vacía no se le abona', () async {
      final id = await _deuda();

      final resultado = await deudores.registrarPago(
        deudorId: id,
        monto: 5000,
        metodoPago: MetodoPago.efectivo,
      );

      expect(resultado, isA<Fallo>());
      expect((resultado as Fallo).mensaje, contains('no tiene saldo'));
    });

    test('anotar una línea reabre la deuda que estaba saldada', () async {
      final id = await _deudaCon(cantidad: 1, precio: 40000);
      await deudores.registrarPago(
        deudorId: id,
        monto: 40000,
        metodoPago: MetodoPago.efectivo,
      );
      expect((await deudores.obtenerDetalle(id)).resumen.estado,
          EstadoDeudor.pagada);

      // Una deuda pagada está cerrada: para agregarle hay que reabrirla.
      await deudores.cambiarEstado(id, EstadoDeudor.activa);
      final resultado = await deudores.agregarItem(
        deudorId: id,
        productoId: taller.productoId,
        cantidad: 1,
        precioUnitario: 50000,
      );

      expect(resultado, isA<Exito>());
      final detalle = await deudores.obtenerDetalle(id);
      expect(detalle.items, hasLength(1),
          reason: 'el mismo producto suma a su línea en vez de abrir otra');
      // Y el precio nuevo pisa al viejo: la línea vale lo que vale hoy, que es
      // lo mismo que hace el carrito y el editor de reservas.
      expect(detalle.resumen.montoTotal, 100000);
      expect(detalle.resumen.estado, EstadoDeudor.activa);
      expect(detalle.resumen.saldo, 60000);
      expect(await deudores.descuadres(), isEmpty);
      expect(await deudores.descuadresTotal(), isEmpty);
    });

    test('no se puede dar por pagada una deuda con saldo', () async {
      final id = await _deudaCon(cantidad: 3, precio: 30000);
      await deudores.registrarPago(
        deudorId: id,
        monto: 10000,
        metodoPago: MetodoPago.efectivo,
      );

      final resultado = await deudores.cambiarEstado(id, EstadoDeudor.pagada);

      expect(resultado, isA<Fallo>());
      // Es justo lo que descuadraría el caché contra la suma de los pagos.
      expect(await deudores.descuadres(), isEmpty);
      expect((await deudores.obtenerDetalle(id)).resumen.estado,
          EstadoDeudor.activa);
    });

    test('borrar el último pago devuelve la deuda a activa', () async {
      final id = await _deudaCon(cantidad: 1, precio: 30000);
      await deudores.registrarPago(
        deudorId: id,
        monto: 30000,
        metodoPago: MetodoPago.efectivo,
      );
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
