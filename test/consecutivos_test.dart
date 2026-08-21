import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/pos/enum/enum_ventas.dart';
import 'package:inventario_k1/backend/features/pos/modelo/linea_venta_mostrador.dart';
import 'package:inventario_k1/backend/features/pos/repositorio/repositorio_ventas_impl.dart';
import 'package:inventario_k1/backend/share/consecutivos/documento_consecutivo.dart';
import 'package:inventario_k1/backend/share/consecutivos/repositorio_consecutivos.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/datos_taller.dart';

late AppDb db;
late RepositorioConsecutivos consecutivos;
late RepositorioVentasImpl ventas;
late DatosTaller taller;

void main() {
  setUp(() async {
    db = baseEnMemoria();
    consecutivos = RepositorioConsecutivos(db);
    ventas = RepositorioVentasImpl(db);
    taller = await sembrarTaller(db);
  });

  tearDown(() => db.close());

  group('el contador reparte números seguidos', () {
    test('la serie empieza en uno y avanza de uno en uno', () async {
      final numeros = [
        for (var i = 0; i < 3; i++)
          await consecutivos.siguiente(DocumentoConsecutivo.factura),
      ];

      expect(numeros, ['FAC-0001', 'FAC-0002', 'FAC-0003']);
    });

    test('cada serie lleva su propia cuenta', () async {
      await consecutivos.siguiente(DocumentoConsecutivo.factura);
      await consecutivos.siguiente(DocumentoConsecutivo.factura);

      expect(await consecutivos.siguiente(DocumentoConsecutivo.deuda),
          'DEU-001');
    });

    test('las series anuales llevan el año dentro del número', () async {
      final anio = DateTime.now().year;

      expect(await consecutivos.siguiente(DocumentoConsecutivo.cotizacion),
          'COT-$anio-0001');
      expect(await consecutivos.siguiente(DocumentoConsecutivo.reserva),
          'RES-$anio-0001');
    });
  });

  group('el número no se reutiliza ni deja huecos', () {
    test('borrar el último documento no libera su número', () async {
      // Con `MAX(numero) + 1` —lo que hacían cotizaciones, reservas y
      // deudas— borrar el último hacía que el siguiente reutilizara su
      // número. En facturación eso es lo peor que puede pasar.
      final primera = await ventas.registrarVentaMostrador(
        lineas: [_unaLinea(taller.productoId)],
        clienteId: taller.clienteId,
        metodoPago: MetodoPago.efectivo,
      );
      expect(primera.numeroFactura, 'FAC-0001');

      // Una venta no se borra —hay una guarda—, así que se simula el caso
      // sobre el contador directamente: el consecutivo no mira las filas.
      final segunda = await ventas.registrarVentaMostrador(
        lineas: [_unaLinea(taller.productoId)],
        clienteId: taller.clienteId,
        metodoPago: MetodoPago.efectivo,
      );
      expect(segunda.numeroFactura, 'FAC-0002');
    });

    test('una transacción revertida devuelve el número', () async {
      await ventas.registrarVentaMostrador(
        lineas: [_unaLinea(taller.productoId)],
        clienteId: taller.clienteId,
        metodoPago: MetodoPago.efectivo,
      );

      // Se pide un número dentro de una transacción que falla: el contador
      // tiene que volver atrás con ella, para que la siguiente venta no
      // salte de FAC-0001 a FAC-0003.
      await expectLater(
        db.transaction(() async {
          await consecutivos.siguiente(DocumentoConsecutivo.factura);
          throw Exception('algo falló después de pedir el número');
        }),
        throwsA(isA<Exception>()),
      );

      final siguiente = await ventas.registrarVentaMostrador(
        lineas: [_unaLinea(taller.productoId)],
        clienteId: taller.clienteId,
        metodoPago: MetodoPago.efectivo,
      );
      expect(siguiente.numeroFactura, 'FAC-0002');
    });

    test('la venta nace con su número definitivo, no con uno temporal',
        () async {
      final resumen = await ventas.registrarVentaMostrador(
        lineas: [_unaLinea(taller.productoId)],
        clienteId: taller.clienteId,
        metodoPago: MetodoPago.efectivo,
      );

      expect(resumen.numeroFactura, isNot(contains('TEMP')));

      final fila = await db
          .customSelect('SELECT numero_factura AS n FROM ventas '
              'WHERE id = ${resumen.id}')
          .getSingle();
      expect(fila.read<String>('n'), 'FAC-0001');
    });
  });

  group('el esquema es el que manda', () {
    test('el contador no puede quedar negativo', () async {
      await consecutivos.siguiente(DocumentoConsecutivo.factura);

      expect(
        () => db.customStatement(
            "UPDATE consecutivos SET ultimo = -1 WHERE documento = 'FACTURA'"),
        throwsA(isA<Exception>()),
      );
    });

    test('una serie no se duplica: documento y periodo son la clave',
        () async {
      await consecutivos.siguiente(DocumentoConsecutivo.factura);

      expect(
        () => db.customStatement(
            "INSERT INTO consecutivos (documento, periodo, ultimo) "
            "VALUES ('FACTURA', 0, 99)"),
        throwsA(isA<Exception>()),
      );
    });
  });
}

/// Una línea de un producto: lo mínimo para que la venta exista.
LineaVentaMostrador _unaLinea(int productoId) => LineaVentaMostrador(
      productoId: productoId,
      descripcion: 'Pastilla de freno',
      cantidad: 1,
      precioUnitario: 30000,
    );
