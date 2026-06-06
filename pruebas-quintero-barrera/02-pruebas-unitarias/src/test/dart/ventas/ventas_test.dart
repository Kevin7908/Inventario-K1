// Pruebas Unitarias — Módulo Transaccional (Ventas / Facturas)
//
// Cómo ejecutar desde la raíz del proyecto Flutter:
//   flutter test pruebas-quintero-barrera/02-pruebas-unitarias/src/test/dart/ventas/ventas_test.dart
//
// Dependencias necesarias (ya en pubspec.yaml):
//   - equatable: ^2.0.8
//   - flutter_test (dev_dependency del SDK de Flutter)

import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/ventas/facturas/enum/enum_facturas.dart';
import 'package:inventario_k1/backend/features/ventas/facturas/modelo/factura_detalle.dart';
import 'package:inventario_k1/backend/features/ventas/facturas/modelo/venta_item.dart';

// ---------------------------------------------------------------------------
// Helpers de construcción reutilizables
// ---------------------------------------------------------------------------

VentaItem _buildItem({
  int id = 1,
  int ventaId = 1,
  TipoItem tipoItem = TipoItem.producto,
  String descripcion = 'Ítem de prueba',
  double cantidad = 1.0,
  double precioUnitario = 100.0,
  double costoUnitario = 60.0,
  double subtotal = 100.0,
}) {
  return VentaItem(
    id: id,
    ventaId: ventaId,
    tipoItem: tipoItem,
    descripcion: descripcion,
    cantidad: cantidad,
    precioUnitario: precioUnitario,
    costoUnitario: costoUnitario,
    subtotal: subtotal,
  );
}

FacturaDetalle _buildFactura({
  int id = 1,
  double total = 500.0,
  double totalPagado = 500.0,
  List<VentaItem>? items,
}) {
  return FacturaDetalle(
    id: id,
    numeroFactura: 'FAC-2026-001',
    tipo: TipoVenta.mostrador,
    clienteNombre: 'Cliente Prueba',
    subtotal: total / 1.19,
    iva: total - (total / 1.19),
    descuento: 0.0,
    total: total,
    totalPagado: totalPagado,
    metodoPago: MetodoPago.efectivo,
    estadoPago: EstadoPago.pagado,
    items: items ?? [],
  );
}

void main() {
  // =========================================================================
  // GROUP 1: Getter saldoPendiente
  // Valida el cálculo de deuda residual = total - totalPagado
  // =========================================================================
  group('Getter saldoPendiente', () {
    test(
      'UT-VT-01: saldoPendiente es 0 cuando totalPagado == total',
      () {
        final factura = _buildFactura(total: 500.0, totalPagado: 500.0);
        expect(factura.saldoPendiente, equals(0.0));
      },
    );

    test(
      'UT-VT-02: saldoPendiente calcula correctamente la diferencia',
      () {
        final factura = _buildFactura(total: 300.0, totalPagado: 100.0);
        expect(factura.saldoPendiente, equals(200.0));
      },
    );

    test(
      'UT-VT-03: saldoPendiente es igual a total cuando no se ha pagado nada',
      () {
        final factura = _buildFactura(total: 150.0, totalPagado: 0.0);
        expect(factura.saldoPendiente, equals(150.0));
      },
    );
  });

  // =========================================================================
  // GROUP 2: Filtros itemsProducto e itemsServicio
  // Valida que los getters filtran correctamente por TipoItem
  // =========================================================================
  group('Filtros itemsProducto e itemsServicio', () {
    late FacturaDetalle facturaConItems;

    setUp(() {
      facturaConItems = _buildFactura(
        items: [
          _buildItem(id: 1, tipoItem: TipoItem.producto, descripcion: 'Aceite'),
          _buildItem(id: 2, tipoItem: TipoItem.servicio, descripcion: 'Cambio aceite'),
          _buildItem(id: 3, tipoItem: TipoItem.producto, descripcion: 'Filtro'),
        ],
      );
    });

    test(
      'UT-VT-04: itemsProducto retorna solo los ítems de tipo producto',
      () {
        final productos = facturaConItems.itemsProducto;
        expect(productos.length, equals(2));
        expect(productos.every((i) => i.tipoItem == TipoItem.producto), isTrue);
      },
    );

    test(
      'UT-VT-05: itemsServicio retorna solo los ítems de tipo servicio',
      () {
        final servicios = facturaConItems.itemsServicio;
        expect(servicios.length, equals(1));
        expect(servicios.first.tipoItem, equals(TipoItem.servicio));
      },
    );

    test(
      'UT-VT-06: itemsProducto e itemsServicio son listas vacías en factura sin ítems',
      () {
        final facturaVacia = _buildFactura(items: []);
        expect(facturaVacia.itemsProducto, isEmpty);
        expect(facturaVacia.itemsServicio, isEmpty);
      },
    );
  });

  // =========================================================================
  // GROUP 3: Parsers de enumeraciones
  // Valida que desdeTexto() y aTexto funcionen correctamente
  // =========================================================================
  group('Parser TipoVenta', () {
    test(
      'UT-VT-07: TipoVenta.desdeTexto parsea "SERVICIO" correctamente',
      () {
        expect(TipoVenta.desdeTexto('SERVICIO'), equals(TipoVenta.servicio));
      },
    );

    test(
      'UT-VT-08: TipoVenta.desdeTexto parsea "MOSTRADOR" correctamente',
      () {
        expect(TipoVenta.desdeTexto('MOSTRADOR'), equals(TipoVenta.mostrador));
      },
    );

    test(
      'UT-VT-09: TipoVenta.aTexto devuelve el nombre en mayúsculas',
      () {
        expect(TipoVenta.servicio.aTexto, equals('SERVICIO'));
        expect(TipoVenta.mostrador.aTexto, equals('MOSTRADOR'));
      },
    );
  });

  group('Parser MetodoPago', () {
    test(
      'UT-VT-10: MetodoPago.desdeTexto parsea los cuatro métodos de pago',
      () {
        expect(MetodoPago.desdeTexto('EFECTIVO'), equals(MetodoPago.efectivo));
        expect(MetodoPago.desdeTexto('TARJETA'), equals(MetodoPago.tarjeta));
        expect(MetodoPago.desdeTexto('TRANSFERENCIA'), equals(MetodoPago.transferencia));
        expect(MetodoPago.desdeTexto('CREDITO'), equals(MetodoPago.credito));
      },
    );

    test(
      'UT-VT-11: MetodoPago.desdeTexto retorna EFECTIVO para texto no reconocido',
      () {
        expect(MetodoPago.desdeTexto('DESCONOCIDO'), equals(MetodoPago.efectivo));
      },
    );
  });

  group('Parser EstadoPago', () {
    test(
      'UT-VT-12: EstadoPago.desdeTexto parsea PAGADO, PENDIENTE y ANULADA',
      () {
        expect(EstadoPago.desdeTexto('PAGADO'), equals(EstadoPago.pagado));
        expect(EstadoPago.desdeTexto('PENDIENTE'), equals(EstadoPago.pendiente));
        expect(EstadoPago.desdeTexto('ANULADA'), equals(EstadoPago.anulada));
      },
    );

    test(
      'UT-VT-13: EstadoPago.desdeTexto retorna PENDIENTE para texto no reconocido — CA-023',
      () {
        expect(EstadoPago.desdeTexto('TEXTO_INVALIDO'), equals(EstadoPago.pendiente));
      },
    );
  });

  // =========================================================================
  // GROUP 4: Equatable en VentaItem
  // Valida que dos VentaItem con los mismos valores son iguales
  // =========================================================================
  group('Equatable — VentaItem', () {
    test(
      'UT-VT-14: Dos VentaItem con mismos valores son iguales (Equatable)',
      () {
        final item1 = _buildItem(id: 99, descripcion: 'Bujía NGK', subtotal: 25.0);
        final item2 = _buildItem(id: 99, descripcion: 'Bujía NGK', subtotal: 25.0);
        expect(item1, equals(item2));
      },
    );

    test(
      'UT-VT-15: VentaItem con distinto id NO es igual',
      () {
        final item1 = _buildItem(id: 1);
        final item2 = _buildItem(id: 2);
        expect(item1, isNot(equals(item2)));
      },
    );
  });
}
