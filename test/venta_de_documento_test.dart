// Cada cobro escribe su venta.
//
// Hasta el 07/09/2026 solo el mostrador escribía en `ventas`, así que los
// repuestos que se iban en una orden de servicio, en una cuenta por cobrar o
// en una reserva no aparecían en ninguna parte donde se pudieran sumar con lo
// demás: el historial y el cuadre del día contaban una fracción de lo que
// entró al taller.
//
// Lo que se fija aquí es lo que se rompería sin que nadie se entere:
//
// - que la factura del documento **no vuelva a mover stock** —la mercancía ya
//   salió cuando se anotó en su documento—;
// - que un documento se facture **una vez**, aunque el gesto se repita;
// - y sobre todo que la orden fiada **no se facture dos veces**: al entregarse
//   y otra vez al saldarse la deuda.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/deudores/repositorio/repositorio_deudores_impl.dart';
import 'package:inventario_k1/backend/features/deudores/resultado/resultado_cierre_credito.dart';
import 'package:inventario_k1/backend/features/ordenes/enum/enum_ordenes.dart';
import 'package:inventario_k1/backend/features/ordenes/repositorio/repositorio_ordenes_impl.dart';
import 'package:inventario_k1/backend/features/pos/enum/enum_ventas.dart';
import 'package:inventario_k1/backend/features/pos/repositorio/repositorio_ventas_impl.dart';
import 'package:inventario_k1/backend/features/reservas/repositorio/repositorio_reservas.dart';
import 'package:inventario_k1/backend/features/reservas/repositorio/repositorio_reservas_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/datos_taller.dart';
import 'soporte/sesion_de_prueba.dart';

late AppDb db;
late SesionActual sesion;
late DatosTaller taller;
late RepositorioVentasImpl ventas;
late RepositorioOrdenesImpl ordenes;
late RepositorioDeudoresImpl deudores;
late RepositorioReservasImpl reservas;

/// El stock que dice el catálogo. Es lo que no puede moverse al facturar.
Future<double> _stock() async {
  final fila = await db
      .customSelect(
        'SELECT stock_actual AS s FROM productos WHERE id = ${taller.productoId}',
      )
      .getSingle();
  return fila.read<double>('s');
}

/// Una orden con un repuesto y una tarea, lista para entregarse.
Future<int> _ordenConTrabajo() async {
  final orden = await ordenes.agregar(
    motoId: taller.motoId,
    clienteId: taller.clienteId,
    kilometrajeEntrada: 12000,
  );
  await ordenes.agregarRepuesto(
    ordenId: orden.id,
    productoId: taller.productoId,
    cantidad: 2,
    precioUnitario: 30000,
  );
  await ordenes.agregarTarea(
    ordenId: orden.id,
    servicioId: taller.servicioId,
    tecnicoId: taller.tecnicoId,
    precioPactado: 40000,
  );
  return orden.id;
}

Future<void> _entregar(int ordenId) => ordenes.actualizar(
      id: ordenId,
      estado: EstadoOrden.entregada,
      kilometrajeEntrada: 12000,
    );

void main() {
  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
    taller = await sembrarTaller(db, stockInicial: 100);
    ventas = RepositorioVentasImpl(db, sesion);
    ordenes = RepositorioOrdenesImpl(db, sesion);
    deudores = RepositorioDeudoresImpl(db, sesion);
    reservas = RepositorioReservasImpl(db, sesion);
  });

  tearDown(() => db.close());

  group('la orden entregada', () {
    test('entra al historial de ventas con todas sus líneas', () async {
      final ordenId = await _ordenConTrabajo();
      await _entregar(ordenId);

      final venta = await ventas.ventaDeDocumento(ordenId: ordenId);
      expect(venta, isNotNull);
      expect(venta!.tipo, TipoVenta.servicio);
      expect(venta.total, 100000, reason: '2 × 30.000 de repuesto + 40.000');

      final detalle = await ventas.obtenerDetalle(venta.id);
      expect(detalle.items, hasLength(2));
      expect(detalle.itemsProducto, hasLength(1));
      expect(detalle.itemsServicio, hasLength(1));
    });

    test('facturarla no vuelve a mover el stock', () async {
      // El repuesto salió del estante al anotarlo en la orden. Descontarlo
      // otra vez al facturar dejaría el inventario en negativo.
      final ordenId = await _ordenConTrabajo();
      final antes = await _stock();

      await _entregar(ordenId);

      expect(await _stock(), antes);
    });

    test('entregarla dos veces no la cobra dos veces', () async {
      final ordenId = await _ordenConTrabajo();
      await _entregar(ordenId);
      await ordenes.actualizar(
        id: ordenId,
        estado: EstadoOrden.lista,
        kilometrajeEntrada: 12000,
      );
      await _entregar(ordenId);

      final cuantas = await db
          .customSelect('SELECT COUNT(*) AS n FROM ventas')
          .getSingle();
      expect(cuantas.read<int>('n'), 1);
    });

    test('una orden sin nada anotado no genera factura', () async {
      final orden = await ordenes.agregar(
        motoId: taller.motoId,
        clienteId: taller.clienteId,
        kilometrajeEntrada: 12000,
      );
      await _entregar(orden.id);

      expect(await ventas.ventaDeDocumento(ordenId: orden.id), isNull);
    });
  });

  group('la orden fiada', () {
    test('no se factura al entregarse: la cobra su deuda', () async {
      // Es el doble cobro que este diseño existe para evitar. `cerrarOrden
      // ACredito` ya deja la orden entregada, así que sin la comprobación la
      // orden entraría al historial y la deuda otra vez al saldarse.
      final ordenId = await _ordenConTrabajo();
      await deudores.cerrarOrdenACredito(ordenId: ordenId);

      expect(await ventas.ventaDeDocumento(ordenId: ordenId), isNull);
    });

    test('reabrirla y volver a entregarla tampoco la factura', () async {
      // `cerrarOrdenACredito` deja la orden `ENTREGADA` con un `UPDATE`
      // propio, así que no pasa por `actualizar` y el cobro doble no ocurre
      // por ahí. Donde sí ocurriría es aquí: alguien devuelve la orden a
      // «lista» desde la pantalla y la vuelve a entregar. Sin la comprobación
      // de que ya está fiada, ese gesto la metería en el historial y la deuda
      // volvería a meterla al saldarse.
      final ordenId = await _ordenConTrabajo();
      await deudores.cerrarOrdenACredito(ordenId: ordenId);

      await ordenes.actualizar(
        id: ordenId,
        estado: EstadoOrden.lista,
        kilometrajeEntrada: 12000,
      );
      await _entregar(ordenId);

      expect(await ventas.ventaDeDocumento(ordenId: ordenId), isNull);
      final cuantas = await db
          .customSelect('SELECT COUNT(*) AS n FROM ventas')
          .getSingle();
      expect(cuantas.read<int>('n'), 0, reason: 'la deuda todavía no se pagó');
    });

    test('la factura sale cuando la deuda termina de pagarse', () async {
      final ordenId = await _ordenConTrabajo();
      final resultado =
          await deudores.cerrarOrdenACredito(ordenId: ordenId);
      final deudorId = (resultado as DeudaAbierta).deudorId;

      await deudores.registrarPago(
        deudorId: deudorId,
        monto: 100000,
        metodoPago: MetodoPago.efectivo,
      );

      final venta = await ventas.ventaDeDocumento(deudorId: deudorId);
      expect(venta, isNotNull);
      expect(venta!.tipo, TipoVenta.deuda);
      expect(venta.total, 100000);

      // Y una sola: la de la deuda, no la de la orden.
      final cuantas = await db
          .customSelect('SELECT COUNT(*) AS n FROM ventas')
          .getSingle();
      expect(cuantas.read<int>('n'), 1);
    });

    test('un pago parcial todavía no factura', () async {
      final ordenId = await _ordenConTrabajo();
      final resultado =
          await deudores.cerrarOrdenACredito(ordenId: ordenId);
      final deudorId = (resultado as DeudaAbierta).deudorId;

      await deudores.registrarPago(
        deudorId: deudorId,
        monto: 40000,
        metodoPago: MetodoPago.efectivo,
      );

      expect(await ventas.ventaDeDocumento(deudorId: deudorId), isNull);
    });

    test('saldar la deuda no vuelve a mover el stock', () async {
      final ordenId = await _ordenConTrabajo();
      final resultado =
          await deudores.cerrarOrdenACredito(ordenId: ordenId);
      final deudorId = (resultado as DeudaAbierta).deudorId;
      final antes = await _stock();

      await deudores.registrarPago(
        deudorId: deudorId,
        monto: 100000,
        metodoPago: MetodoPago.efectivo,
      );

      expect(await _stock(), antes);
    });
  });

  group('la reserva', () {
    test('entra al historial cuando se termina de abonar', () async {
      final reservaId = await reservas.crear(
        clienteId: taller.clienteId,
        totalReserva: 0,
        fechaLimite: null,
        items: [
          ItemReservaDraft(
            productoId: taller.productoId,
            cantidad: 2,
            precioUnitario: 30000,
          ),
        ],
      );

      await reservas.registrarAbono(
        reservaId: reservaId,
        monto: 60000,
        metodoPago: MetodoPago.efectivo,
      );

      final venta = await ventas.ventaDeDocumento(reservaId: reservaId);
      expect(venta, isNotNull);
      expect(venta!.tipo, TipoVenta.reserva);
      expect(venta.total, 60000);
    });

    test('con abono parcial todavía no factura', () async {
      final reservaId = await reservas.crear(
        clienteId: taller.clienteId,
        totalReserva: 0,
        fechaLimite: null,
        items: [
          ItemReservaDraft(
            productoId: taller.productoId,
            cantidad: 2,
            precioUnitario: 30000,
          ),
        ],
      );

      await reservas.registrarAbono(
        reservaId: reservaId,
        monto: 20000,
        metodoPago: MetodoPago.efectivo,
      );

      expect(await ventas.ventaDeDocumento(reservaId: reservaId), isNull);
    });

    test('terminar de abonar no vuelve a mover el stock', () async {
      final reservaId = await reservas.crear(
        clienteId: taller.clienteId,
        totalReserva: 0,
        fechaLimite: null,
        items: [
          ItemReservaDraft(
            productoId: taller.productoId,
            cantidad: 2,
            precioUnitario: 30000,
          ),
        ],
      );
      final antes = await _stock();

      await reservas.registrarAbono(
        reservaId: reservaId,
        monto: 60000,
        metodoPago: MetodoPago.efectivo,
      );

      expect(await _stock(), antes);
    });
  });
}
