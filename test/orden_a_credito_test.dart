// Cerrar una orden a crédito: la deuda copia lo que la orden cobra y **no
// vuelve a tocar el inventario**.
//
// Es el descuadre que el proyecto tenía abierto. El caso era este: se anotaba
// el repuesto en la orden —y salía del estante—, el cliente pedía fiado, y en
// Cuentas por cobrar se anotaba otra vez el mismo repuesto para que constara
// qué debía. Salía uno del taller y el inventario decía que salieron dos.
//
// Por eso el test que más importa de este archivo es el que cuenta los
// renglones del libro mayor antes y después de fiar.
import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/deudores/enum/enum_deudor.dart';
import 'package:inventario_k1/backend/features/deudores/repositorio/repositorio_deudores_impl.dart';
import 'package:inventario_k1/backend/features/deudores/resultado/resultado_cierre_credito.dart';
import 'package:inventario_k1/backend/features/inventario/repositorio/repositorio_inventario_impl.dart';
import 'package:inventario_k1/backend/features/ordenes/enum/enum_ordenes.dart';
import 'package:inventario_k1/backend/features/ordenes/repositorio/repositorio_ordenes_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/permiso.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';
import 'package:inventario_k1/core/resultado.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/datos_taller.dart';
import 'soporte/sesion_de_prueba.dart';

late AppDb db;
late SesionActual sesion;
late RepositorioOrdenesImpl ordenes;
late RepositorioDeudoresImpl deudores;
late RepositorioInventarioImpl inventario;
late DatosTaller taller;

/// Una orden con las tres clases de línea: repuesto, mano de obra y cargo
/// suelto. Es la que hay que poder fiar entera.
///
/// 2 pastillas × 30.000 + 45.000 de mano de obra + 12.000 de lavada =
/// 117.000.
Future<int> _ordenCompleta({int descuento = 0}) async {
  final orden = await ordenes.agregar(
    motoId: taller.motoId,
    clienteId: taller.clienteId,
    kilometrajeEntrada: 32000,
    diagnostico: 'Frena raspando',
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
    precioPactado: 45000,
  );
  await ordenes.agregarCargo(
    ordenId: orden.id,
    descripcion: 'Lavada de motor',
    precio: 12000,
  );

  if (descuento > 0) {
    await ordenes.fijarDescuento(id: orden.id, valor: descuento);
  }
  return orden.id;
}

Future<double> _stock() async {
  final fila = await db
      .customSelect('SELECT stock_actual AS s FROM productos WHERE id = ?',
          variables: [Variable.withInt(taller.productoId)])
      .getSingle();
  return fila.read<double>('s');
}

/// Cuántos renglones hay en el libro mayor, sin importar de dónde vengan.
Future<int> _movimientos() async {
  final fila = await db
      .customSelect('SELECT COUNT(*) AS n FROM movimientos_inventario')
      .getSingle();
  return fila.read<int>('n');
}

void main() {
  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
    ordenes = RepositorioOrdenesImpl(db, sesion);
    deudores = RepositorioDeudoresImpl(db, sesion);
    inventario = RepositorioInventarioImpl(db, sesion);
    taller = await sembrarTaller(db, stockInicial: 10);
  });

  tearDown(() => db.close());

  group('fiar una orden no descuenta el repuesto por segunda vez', () {
    test('el stock y el libro mayor quedan como los dejó la orden', () async {
      final ordenId = await _ordenCompleta();

      final stockTrasLaOrden = await _stock();
      final renglonesTrasLaOrden = await _movimientos();
      expect(stockTrasLaOrden, 8, reason: 'las dos pastillas ya salieron');

      final r = await deudores.cerrarOrdenACredito(ordenId: ordenId);

      expect(r, isA<DeudaAbierta>());
      expect(await _stock(), stockTrasLaOrden,
          reason: 'fiar no vuelve a sacar lo que ya salió');
      expect(await _movimientos(), renglonesTrasLaOrden,
          reason: 'ni deja un renglón nuevo en el libro mayor');
      expect(await inventario.descuadres(), isEmpty);
    });

    test('la deuda no tiene ni un movimiento a su nombre', () async {
      final ordenId = await _ordenCompleta();
      final r = await deudores.cerrarOrdenACredito(ordenId: ordenId)
          as DeudaAbierta;

      final fila = await db.customSelect(
        'SELECT COUNT(*) AS n FROM movimientos_inventario WHERE deudor_id = ?',
        variables: [Variable.withInt(r.deudorId)],
      ).getSingle();

      expect(fila.read<int>('n'), 0);
    });
  });

  group('la deuda dice lo mismo que la orden', () {
    test('trae repuestos, mano de obra y cargos, con su descripción',
        () async {
      final ordenId = await _ordenCompleta();
      final r = await deudores.cerrarOrdenACredito(ordenId: ordenId)
          as DeudaAbierta;

      final detalle = await deudores.obtenerDetalle(r.deudorId);

      expect(detalle.items, hasLength(3));
      expect(
        detalle.items.map((i) => i.descripcion),
        ['Pastilla de freno', 'Sincronización', 'Lavada de motor'],
      );
      expect(detalle.items.first.esProducto, isTrue);
      expect(detalle.items.first.sku, 'FRE-1');
      expect(detalle.items[1].esProducto, isFalse,
          reason: 'la mano de obra no es una pieza del catálogo');
      expect(detalle.resumen.montoTotal, 117000);
      expect(await deudores.descuadresTotal(), isEmpty);
    });

    test('el descuento de la orden viaja con ella', () async {
      // Sin la columna `descuento`, la deuda se abriría por 117.000 cuando la
      // orden solo cobra 100.000.
      final ordenId = await _ordenCompleta(descuento: 17000);
      final r = await deudores.cerrarOrdenACredito(ordenId: ordenId)
          as DeudaAbierta;

      final detalle = await deudores.obtenerDetalle(r.deudorId);
      expect(detalle.resumen.descuento, 17000);
      expect(detalle.resumen.montoTotal, 100000);
      expect(await deudores.descuadresTotal(), isEmpty);
    });

    test('la orden queda entregada y las dos enlazadas', () async {
      final ordenId = await _ordenCompleta();
      final r = await deudores.cerrarOrdenACredito(ordenId: ordenId)
          as DeudaAbierta;

      final orden = await ordenes.obtenerDetalle(ordenId);
      expect(orden.estado, EstadoOrden.entregada);
      expect(orden.fechaSalida, isNotNull);

      final deuda = (await deudores.obtenerDetalle(r.deudorId)).resumen;
      expect(deuda.ordenId, ordenId);
      expect(deuda.numeroOrden, orden.numeroOrden);
      expect(deuda.vieneDeOrden, isTrue);
      expect(deuda.estado, EstadoDeudor.activa);
    });

    test('el cliente y la moto salen de la orden', () async {
      final ordenId = await _ordenCompleta();
      final r = await deudores.cerrarOrdenACredito(ordenId: ordenId)
          as DeudaAbierta;

      final deuda = (await deudores.obtenerDetalle(r.deudorId)).resumen;
      expect(deuda.clienteId, taller.clienteId);
      expect(deuda.motoId, taller.motoId);
    });
  });

  group('lo que el cierre a crédito rechaza', () {
    test('una orden ya fiada no se fía otra vez', () async {
      final ordenId = await _ordenCompleta();
      await deudores.cerrarOrdenACredito(ordenId: ordenId);

      final segundo = await deudores.cerrarOrdenACredito(ordenId: ordenId);

      expect(segundo, isA<CierreRechazado>());
      expect((segundo as CierreRechazado).mensaje, contains('ya se fió'));
    });

    test('una orden sin líneas no abre deuda', () async {
      final orden = await ordenes.agregar(
        motoId: taller.motoId,
        clienteId: taller.clienteId,
        kilometrajeEntrada: 1000,
      );

      final r = await deudores.cerrarOrdenACredito(ordenId: orden.id);

      expect(r, isA<CierreRechazado>());
      expect((r as CierreRechazado).motivo, MotivoFallo.validacion);
    });

    test('una orden anulada tampoco', () async {
      final ordenId = await _ordenCompleta();
      await ordenes.actualizar(
        id: ordenId,
        estado: EstadoOrden.anulada,
        kilometrajeEntrada: 32000,
      );

      final r = await deudores.cerrarOrdenACredito(ordenId: ordenId);

      expect(r, isA<CierreRechazado>());
    });

    test('sin los dos permisos no se cierra nada', () async {
      // Abre una deuda y cierra una orden: hacen falta los dos.
      final soloDeudas = await sesionDePrueba(
        db,
        permisos: {Permiso.deudoresCrear},
        usuario: 'cajero',
      );
      final ordenId = await _ordenCompleta();

      final r = await RepositorioDeudoresImpl(db, soloDeudas)
          .cerrarOrdenACredito(ordenId: ordenId);

      expect(r, isA<CierreRechazado>());
      expect((r as CierreRechazado).motivo, MotivoFallo.validacion);
      final deudas = await db
          .customSelect('SELECT COUNT(*) AS n FROM deudores')
          .getSingle();
      expect(deudas.read<int>('n'), 0, reason: 'no se abrió ninguna');
    });
  });

  group('la deuda que copia una orden está cerrada a la edición', () {
    test('el repositorio rechaza agregarle una línea', () async {
      final ordenId = await _ordenCompleta();
      final r = await deudores.cerrarOrdenACredito(ordenId: ordenId)
          as DeudaAbierta;

      final fallo = await deudores.agregarItem(
        deudorId: r.deudorId,
        productoId: taller.productoId,
        cantidad: 1,
        precioUnitario: 30000,
      );

      expect(fallo, isA<Fallo>());
      expect((fallo as Fallo).mensaje, contains('se corrigen en la orden'));
      expect(await _stock(), 8, reason: 'y no movió inventario');
    });

    test('la guarda de la base lo impide aunque se escriba a mano', () async {
      // Es la garantía de verdad: el repositorio da el mensaje, la base cierra
      // la puerta (`REGLAS_BD.md` §3.4).
      final ordenId = await _ordenCompleta();
      final r = await deudores.cerrarOrdenACredito(ordenId: ordenId)
          as DeudaAbierta;

      expect(
        () => db.into(db.tablaDeudorItem).insert(
              TablaDeudorItemCompanion.insert(
                usuarioId: sesion.usuarioId,
                deudorId: r.deudorId,
                productoId: Value(taller.productoId),
                descripcion: 'Colada por la puerta de atrás',
                cantidad: 1,
                precioUnitario: 30000,
              ),
            ),
        throwsA(isA<Exception>()),
      );

      expect(
        () => db.customStatement(
          'DELETE FROM deudor_items WHERE deudor_id = ${r.deudorId}',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('desenlazar la deuda de su orden tampoco es un camino', () async {
      final ordenId = await _ordenCompleta();
      final r = await deudores.cerrarOrdenACredito(ordenId: ordenId)
          as DeudaAbierta;

      expect(
        () => db.customStatement(
          'UPDATE deudores SET orden_id = NULL WHERE id = ${r.deudorId}',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('la orden fiada no se puede borrar, y el mensaje dice por qué',
        () async {
      final ordenId = await _ordenCompleta();
      final r = await deudores.cerrarOrdenACredito(ordenId: ordenId)
          as DeudaAbierta;

      expect(
        () => ordenes.eliminar(ordenId),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'mensaje',
            contains(r.numero),
          ),
        ),
      );
    });

    test('borrarla no devuelve al estante lo que sigue en la moto', () async {
      // Borrar una deuda de mostrador sí devuelve: significa que nunca debió
      // anotarse. Esta es otra cosa —los repuestos los sigue debiendo la
      // orden—, y devolverlos inflaría el inventario.
      final ordenId = await _ordenCompleta();
      final r = await deudores.cerrarOrdenACredito(ordenId: ordenId)
          as DeudaAbierta;

      await deudores.eliminar(r.deudorId);

      expect(await _stock(), 8);
      expect(await inventario.descuadres(), isEmpty);
    });
  });
}
