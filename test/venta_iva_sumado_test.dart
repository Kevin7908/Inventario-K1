// El caso que reportó el taller, contra la base de verdad.
//
// `iva_sumado_test.dart` prueba la aritmética; esto prueba que la venta
// **guardada** cuadre: que `total = subtotal − descuento + iva` en la fila, no
// solo en el estado del carrito. Es donde estaba el bug: el POS pintaba el IVA
// y el total nunca lo sumaba.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/pos/enum/enum_ventas.dart';
import 'package:inventario_k1/backend/features/pos/modelo/linea_venta_mostrador.dart';
import 'package:inventario_k1/backend/features/pos/repositorio/repositorio_ventas_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';
import 'package:inventario_k1/core/iva_app.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/datos_taller.dart';
import 'soporte/sesion_de_prueba.dart';

late AppDb db;
late SesionActual sesion;
late RepositorioVentasImpl ventas;
late DatosTaller taller;

/// Vende [cantidad] unidades a [precioUnitario] y devuelve el detalle guardado.
Future<int> _vender({
  double cantidad = 1,
  int precioUnitario = 10000,
  int descuento = 0,
}) async {
  final resumen = await ventas.registrarVentaMostrador(
    metodoPago: MetodoPago.efectivo,
    descuento: descuento,
    lineas: [
      LineaVentaMostrador(
        productoId: taller.productoId,
        descripcion: 'Pastilla de freno',
        cantidad: cantidad,
        precioUnitario: precioUnitario,
        costoUnitario: 5000,
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
    taller = await sembrarTaller(db, stockInicial: 100);
  });

  tearDown(() async {
    configurarIva(0);
    await db.close();
  });

  test('un producto de 10.000 al 19% se guarda cobrado en 11.900', () async {
    configurarIva(19);
    final detalle = await ventas.obtenerDetalle(await _vender());

    expect(detalle.subtotal, 10000);
    expect(detalle.iva, 1900);
    expect(detalle.total, 11900);
    expect(detalle.totalPagado, 11900, reason: 'se cobró el total con IVA');
  });

  test('el descuento se resta antes de liquidar el impuesto', () async {
    configurarIva(19);
    final detalle = await ventas.obtenerDetalle(
      await _vender(precioUnitario: 100000, descuento: 20000),
    );

    expect(detalle.subtotal, 100000);
    expect(detalle.descuento, 20000);
    expect(detalle.iva, 15200, reason: '19% de 80.000, no de 100.000');
    expect(detalle.total, 95200);
  });

  test('sin tasa configurada el total es el subtotal', () async {
    final detalle = await ventas.obtenerDetalle(await _vender());

    expect(detalle.iva, 0);
    expect(detalle.total, 10000);
  });

  test('bajar la tasa después no reescribe la factura de ayer', () async {
    configurarIva(19);
    final id = await _vender();

    configurarIva(0);
    final detalle = await ventas.obtenerDetalle(id);

    expect(detalle.iva, 1900, reason: 'el IVA es el del día en que se cerró');
    expect(detalle.total, 11900);
  });

  test('el vendedor solo se guarda cuando no es quien cobra', () async {
    // Vender y cobrar la misma persona es el caso normal, y la columna guarda
    // la excepción: repetir el mismo id en las dos sería el dato duplicado que
    // prohíbe `REGLAS_BD.md` §1.1.
    final propia = await ventas.registrarVentaMostrador(
      metodoPago: MetodoPago.efectivo,
      vendedorId: sesion.usuarioId,
      lineas: [
        LineaVentaMostrador(
          productoId: taller.productoId,
          descripcion: 'Pastilla de freno',
          cantidad: 1,
          precioUnitario: 10000,
          costoUnitario: 5000,
        ),
      ],
    );

    final fila = await db
        .customSelect('SELECT vendedor_id FROM ventas WHERE id = ${propia.id}')
        .getSingle();

    expect(fila.data['vendedor_id'], isNull);
    expect((await ventas.obtenerDetalle(propia.id)).vendedor, isEmpty);
  });
}
