import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/inventario/repositorio/repositorio_inventario_impl.dart';
import 'package:inventario_k1/backend/features/reservas/enum/enum_reserva.dart';
import 'package:inventario_k1/backend/features/reservas/repositorio/repositorio_reservas.dart';
import 'package:inventario_k1/backend/features/reservas/repositorio/repositorio_reservas_impl.dart';
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

/// Crea una reserva de una sola línea.
///
/// **No recibe el total**: es la suma de sus líneas, y quien lo fijaba a mano
/// era justo lo que dejaba el caché descuadrado desde el primer día. Para un
/// total concreto se ajustan [cantidad] y [precio].
Future<int> _reserva({
  double cantidad = 2,
  int precio = 30000,
  int abonoInicial = 0,
}) =>
    reservas.crear(
      clienteId: taller.clienteId,
      fechaLimite: DateTime.now().add(const Duration(days: 30)),
      totalReserva: 0, // provisional: lo pisa la suma de las líneas
      abonoInicial: abonoInicial,
      items: [
        ItemReservaDraft(
          productoId: taller.productoId,
          cantidad: cantidad,
          precioUnitario: precio,
        ),
      ],
    );

/// La línea única de la reserva, para poder editarla.
Future<int> _itemDe(int reservaId) async =>
    (await reservas.obtenerDetalle(reservaId)).items.single.id;

void main() {
  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
    reservas = RepositorioReservasImpl(db, sesion);
    inventario = RepositorioInventarioImpl(db, sesion);
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
      final id = await _reserva(cantidad: 2, precio: 50000, abonoInicial: 40000);

      final detalle = await reservas.obtenerDetalle(id);
      expect(detalle.abonos, hasLength(1));
      expect(detalle.resumen.pagadoAcumulado, 40000);
      expect(await reservas.descuadres(), isEmpty);
    });

    test('cada abono nuevo recalcula el caché', () async {
      final id = await _reserva(cantidad: 2, precio: 50000, abonoInicial: 40000);

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

    test('terminar de pagar no cierra la reserva sola', () async {
      // Pagar y entregar son cosas distintas: la mercancía sigue en la bodega
      // hasta que alguien la despacha. Si pagar cerrara la reserva, y una
      // reserva cerrada no se edita, el cliente que paga todo y después dice
      // «agrégame un filtro» se quedaría sin poder hacerlo.
      final id = await _reserva(cantidad: 2, precio: 30000);

      await reservas.registrarAbono(
        reservaId: id,
        monto: 60000,
        metodoPago: MetodoPago.efectivo,
      );

      final detalle = await reservas.obtenerDetalle(id);
      expect(detalle.resumen.estado, EstadoReserva.activa);
      expect(detalle.resumen.pagada, isTrue, reason: 'el dinero sí está');
      expect(detalle.resumen.saldo, 0);
    });

    test('no se puede abonar más de lo que falta', () async {
      final id = await _reserva(cantidad: 2, precio: 30000, abonoInicial: 50000);

      // Se comprueba **el mensaje** y no solo que lance: el `CHECK` de la
      // tabla también lo impediría, pero con un error de SQLite que no se le
      // puede enseñar a nadie. Sin esto, quitar la validación del repositorio
      // dejaba el test en verde.
      await expectLater(
        () => reservas.registrarAbono(
          reservaId: id,
          monto: 20000, // faltan 10.000
          metodoPago: MetodoPago.efectivo,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'mensaje',
            allOf(contains('saldo'), contains('10000')),
          ),
        ),
      );

      final detalle = await reservas.obtenerDetalle(id);
      expect(detalle.resumen.pagadoAcumulado, 50000);
      expect(await reservas.descuadres(), isEmpty);
    });

    test('descuadres delata al que escribe el caché por fuera', () async {
      final id = await _reserva(cantidad: 2, precio: 50000, abonoInicial: 40000);

      await db.customStatement(
        'UPDATE reservas SET pagado_acumulado = 50000 WHERE id = $id',
      );

      expect(await reservas.descuadres(), {id: 10000});
    });
  });

  group('las líneas se escriben una a una', () {
    // El editor escribe por línea y no reemplazando la reserva entera: con la
    // vía vieja, cada tecleo restauraba y volvía a descontar el stock de todas
    // las líneas —dos movimientos por línea y por tecla—.

    test('agregar una línea aparta la mercancía y sube el total', () async {
      final id = await _reserva(cantidad: 2, precio: 30000);
      expect(await _stock(), 8);

      final r = await reservas.agregarItem(
        reservaId: id,
        productoId: taller.productoId,
        cantidad: 3,
        precioUnitario: 30000,
      );

      expect(r, isA<Exito>());
      expect(await _stock(), 5);
      final detalle = await reservas.obtenerDetalle(id);
      expect(detalle.resumen.totalReserva, 150000);
      expect(await reservas.descuadresTotal(), isEmpty);
      expect(await inventario.descuadres(), isEmpty);
    });

    test('el mismo producto se suma a su línea, no abre otra', () async {
      final id = await _reserva(cantidad: 2, precio: 30000);

      await reservas.agregarItem(
        reservaId: id,
        productoId: taller.productoId,
        cantidad: 1,
        precioUnitario: 30000,
      );

      final detalle = await reservas.obtenerDetalle(id);
      expect(detalle.items, hasLength(1));
      expect(detalle.items.single.cantidad, 3);
    });

    test('sin stock la línea no llega a existir', () async {
      final id = await _reserva(cantidad: 2, precio: 30000);

      final r = await reservas.agregarItem(
        reservaId: id,
        productoId: taller.productoId,
        cantidad: 99,
        precioUnitario: 30000,
      );

      expect(r, isA<Fallo>());
      expect(await _stock(), 8, reason: 'no se movió nada');
      expect((await reservas.obtenerDetalle(id)).items, hasLength(1));
    });

    test('subir la cantidad aparta solo la diferencia', () async {
      final id = await _reserva(cantidad: 2, precio: 30000);

      await reservas.actualizarItem(await _itemDe(id), cantidad: 5);

      expect(await _stock(), 5, reason: '10 - 2 - 3, no 10 - 2 - 5');
      final detalle = await reservas.obtenerDetalle(id);
      expect(detalle.resumen.totalReserva, 150000);
      expect(await inventario.descuadres(), isEmpty);
    });

    test('bajar la cantidad devuelve la diferencia', () async {
      final id = await _reserva(cantidad: 5, precio: 30000);

      await reservas.actualizarItem(await _itemDe(id), cantidad: 2);

      expect(await _stock(), 8);
      expect((await reservas.obtenerDetalle(id)).resumen.totalReserva, 60000);
      expect(await inventario.descuadres(), isEmpty);
    });

    test('quitar la línea devuelve la mercancía y deja el total en cero',
        () async {
      final id = await _reserva(cantidad: 3, precio: 30000);

      await reservas.eliminarItem(await _itemDe(id));

      expect(await _stock(), 10);
      expect((await reservas.obtenerDetalle(id)).resumen.totalReserva, 0);
      expect(await reservas.descuadresTotal(), isEmpty);
    });
  });

  group('quitar mercancía ya abonada devuelve la plata', () {
    test('el sobrante entra como abono negativo', () async {
      // Apartó 100.000 y entregó 80.000. Se arrepiente de la mitad: el total
      // queda en 50.000 y hay 30.000 que hay que regresarle.
      final id = await _reserva(cantidad: 2, precio: 50000, abonoInicial: 80000);

      await reservas.actualizarItem(await _itemDe(id), cantidad: 1);

      final detalle = await reservas.obtenerDetalle(id);
      expect(detalle.resumen.totalReserva, 50000);
      expect(detalle.resumen.pagadoAcumulado, 50000);
      expect(detalle.resumen.saldo, 0);

      final devolucion = detalle.abonos.where((a) => a.monto < 0);
      expect(devolucion, hasLength(1));
      expect(devolucion.single.monto, -30000);
      expect(await reservas.descuadres(), isEmpty);
    });

    test('si el total sigue por encima de lo abonado no devuelve nada',
        () async {
      final id = await _reserva(cantidad: 3, precio: 50000, abonoInicial: 40000);

      await reservas.actualizarItem(await _itemDe(id), cantidad: 2);

      final detalle = await reservas.obtenerDetalle(id);
      expect(detalle.resumen.totalReserva, 100000);
      expect(detalle.resumen.pagadoAcumulado, 40000);
      expect(detalle.abonos.where((a) => a.monto < 0), isEmpty);
    });

    test('quitarlo todo devuelve todo lo entregado', () async {
      final id = await _reserva(cantidad: 2, precio: 50000, abonoInicial: 60000);

      await reservas.eliminarItem(await _itemDe(id));

      final detalle = await reservas.obtenerDetalle(id);
      expect(detalle.resumen.totalReserva, 0);
      expect(detalle.resumen.pagadoAcumulado, 0);
      expect(detalle.abonos.where((a) => a.monto < 0).single.monto, -60000);
      expect(await reservas.descuadres(), isEmpty);
    });
  });

  group('solo una reserva activa se edita', () {
    test('una cancelada no admite líneas nuevas', () async {
      final id = await _reserva(cantidad: 2, precio: 30000);
      await reservas.cambiarEstado(id, EstadoReserva.cancelada);
      expect(await _stock(), 10, reason: 'cancelar ya devolvió la mercancía');

      final r = await reservas.agregarItem(
        reservaId: id,
        productoId: taller.productoId,
        cantidad: 1,
        precioUnitario: 30000,
      );

      expect(r, isA<Fallo>());
      expect(await _stock(), 10, reason: 'no volvió a descontar');
    });

    test('una completada tampoco', () async {
      final id = await _reserva(cantidad: 2, precio: 30000);
      await reservas.cambiarEstado(id, EstadoReserva.completada);

      final r = await reservas.eliminarItem(await _itemDe(id));

      expect(r, isA<Fallo>());
      expect((await reservas.obtenerDetalle(id)).items, hasLength(1));
    });

    test('editar una cancelada ya no la revive', () async {
      // Antes `actualizar` forzaba estado ACTIVA, así que esto la resucitaba
      // y le volvía a descontar el stock que cancelar había devuelto.
      final id = await _reserva(cantidad: 2, precio: 30000);
      await reservas.cambiarEstado(id, EstadoReserva.cancelada);

      await expectLater(
        () => reservas.actualizar(
          id: id,
          fechaLimite: null,
          totalReserva: 60000,
          items: [
            ItemReservaDraft(
              productoId: taller.productoId,
              cantidad: 2,
              precioUnitario: 30000,
            ),
          ],
        ),
        throwsA(isA<Exception>()),
      );

      final detalle = await reservas.obtenerDetalle(id);
      expect(detalle.resumen.estado, EstadoReserva.cancelada);
      expect(await _stock(), 10);
    });
  });

  group('el listado se pagina en SQL', () {
    Future<void> sembrar(int cuantas) async {
      for (var i = 0; i < cuantas; i++) {
        await _reserva(cantidad: 1, precio: 1000);
      }
    }

    test('el LIMIT recorta la página pero el total sigue siendo el real',
        () async {
      await sembrar(5);

      final pagina = await reservas
          .observarPagina(
            filtro: const FiltroReservas(),
            pagina: 0,
            tamano: 2,
          )
          .first;

      expect(pagina.items, hasLength(2));
      expect(pagina.total, 5);
    });

    test('el filtro de estado recorta en SQL y el total lo acompaña', () async {
      await sembrar(3);
      final todas = await reservas.obtenerTodas();
      await reservas.cambiarEstado(todas.first.id, EstadoReserva.cancelada);

      final pagina = await reservas
          .observarPagina(
            filtro: const FiltroReservas(estado: EstadoReserva.activa),
            pagina: 0,
            tamano: 10,
          )
          .first;

      expect(pagina.total, 2);
      expect(pagina.items.every((r) => r.estado == EstadoReserva.activa), isTrue);
    });

    test('la búsqueda mira el número y el nombre del cliente', () async {
      final id = await _reserva(cantidad: 1, precio: 1000);
      final numero = (await reservas.obtenerDetalle(id)).resumen.numero;

      final porNumero = await reservas
          .observarPagina(
            filtro: FiltroReservas(busqueda: numero),
            pagina: 0,
            tamano: 10,
          )
          .first;
      expect(porNumero.total, 1);

      final porCliente = await reservas
          .observarPagina(
            filtro: const FiltroReservas(busqueda: 'carlos'),
            pagina: 0,
            tamano: 10,
          )
          .first;
      expect(porCliente.total, 1);

      final sinNada = await reservas
          .observarPagina(
            filtro: const FiltroReservas(busqueda: 'zzz'),
            pagina: 0,
            tamano: 10,
          )
          .first;
      expect(sinNada.total, 0);
    });
  });

  group('una cotización no se reserva dos veces', () {
    /// El sembrado del taller no crea cotizaciones, así que la pone el test.
    Future<int> cotizacion() => db.into(db.tablaCotizacion).insert(
          TablaCotizacionCompanion.insert(
            usuarioId: sesion.usuarioId,
            numero: 'COT-TEST-${DateTime.now().microsecondsSinceEpoch}',
            clienteId: Value(taller.clienteId),
            vigenciaHasta: DateTime.now().add(const Duration(days: 15)),
          ),
        );

    test('la UNIQUE lo impide en la base', () async {
      final cid = await cotizacion();
      await reservas.crear(
        clienteId: taller.clienteId,
        cotizacionId: cid,
        fechaLimite: null,
        totalReserva: 0,
        items: [
          ItemReservaDraft(
            productoId: taller.productoId,
            cantidad: 1,
            precioUnitario: 1000,
          ),
        ],
      );

      await expectLater(
        () => reservas.crear(
          clienteId: taller.clienteId,
          cotizacionId: cid,
          fechaLimite: null,
          totalReserva: 0,
          items: [
            ItemReservaDraft(
              productoId: taller.productoId,
              cantidad: 1,
              precioUnitario: 1000,
            ),
          ],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('reservaDeCotizacion encuentra la que ya existe', () async {
      final cid = await cotizacion();
      expect(await reservas.reservaDeCotizacion(cid), isNull);

      final id = await reservas.crear(
        clienteId: taller.clienteId,
        cotizacionId: cid,
        fechaLimite: null,
        totalReserva: 0,
        items: [
          ItemReservaDraft(
            productoId: taller.productoId,
            cantidad: 1,
            precioUnitario: 1000,
          ),
        ],
      );

      expect(await reservas.reservaDeCotizacion(cid), id);
    });

    test('dos reservas sin cotización no chocan entre sí', () async {
      // La columna es UNIQUE pero nullable, y en SQLite los NULL no compiten:
      // si compitieran, solo podría existir una reserva de mostrador.
      await _reserva(cantidad: 1, precio: 1000);
      await _reserva(cantidad: 1, precio: 1000);

      expect(await reservas.obtenerTodas(), hasLength(2));
    });
  });

  group('los CHECK del esquema', () {
    test('no se puede recibir más de lo pactado', () async {
      final id = await _reserva(cantidad: 1, precio: 50000);

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
                usuarioId: sesion.usuarioId,
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
                usuarioId: sesion.usuarioId,
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
                usuarioId: sesion.usuarioId,
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
              usuarioId: sesion.usuarioId,
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

  group('clics rápidos sobre la misma tarjeta', () {
    // El usuario reportó que «al clickear muy rápido se buguea». La adición
    // escribe en la base por cada clic, así que cinco toques seguidos lanzan
    // cinco escrituras solapadas sobre la misma línea. `agregarItem` hace
    // leer-modificar-escribir para sumar a la línea existente, y eso es
    // exactamente la forma que pierde incrementos si dos se cruzan.
    test('cinco adiciones concurrentes dejan las cinco unidades', () async {
      final id = await _reserva(cantidad: 1);

      await Future.wait([
        for (var i = 0; i < 5; i++)
          reservas.agregarItem(
            reservaId: id,
            productoId: taller.productoId,
            cantidad: 1,
            precioUnitario: 30000,
          ),
      ]);

      final detalle = await reservas.obtenerDetalle(id);
      expect(detalle.items, hasLength(1),
          reason: 'el mismo producto no puede abrir cinco líneas');
      expect(detalle.items.single.cantidad, 6,
          reason: 'la de la reserva más las cinco apartadas');
      expect(await inventario.descuadres(), isEmpty,
          reason: 'el stock tiene que cuadrar con el libro mayor');
    });
  });
}
