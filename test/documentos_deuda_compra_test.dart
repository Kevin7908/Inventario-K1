// Los dos traductores que faltaban: la cuenta por cobrar y la remisión de
// entrada.
//
// Lo que se prueba es la **traducción**, no el dibujo, igual que en
// `documentos_factura_test.dart`: qué se esconde, qué se rotula y de dónde sale
// cada cifra. Que un renglón quede a 240 pt del margen no lo sabe nadie hasta
// verlo impreso; que la remisión diga «Proveedor» y no «Cliente», sí.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/compras/enum/enum_compras.dart';
import 'package:inventario_k1/backend/features/compras/modelo/compra_item.dart';
import 'package:inventario_k1/backend/features/compras/modelo/compra_resumen.dart';
import 'package:inventario_k1/backend/features/deudores/enum/enum_deudor.dart';
import 'package:inventario_k1/backend/features/deudores/modelo/deudor_detalle.dart';
import 'package:inventario_k1/backend/features/deudores/modelo/deudor_item.dart';
import 'package:inventario_k1/backend/features/deudores/modelo/deudor_pago.dart';
import 'package:inventario_k1/backend/features/deudores/modelo/deudor_resumen.dart';
import 'package:inventario_k1/backend/share/dominio/metodo_pago.dart';
import 'package:inventario_k1/core/iva_app.dart';
import 'package:inventario_k1/frontend/features/documentos/modelo/negocio_impreso.dart';
import 'package:inventario_k1/frontend/features/documentos/servicio/constructor_pdf.dart';
import 'package:inventario_k1/frontend/features/documentos/traductores/compra_a_documento.dart';
import 'package:inventario_k1/frontend/features/documentos/traductores/deuda_a_documento.dart';

const _negocio = NegocioImpreso(
  nombre: 'Taller K1',
  nit: '901.555.222-8',
  ciudad: 'Cali',
);

DeudorItem _itemDeuda({
  int id = 1,
  int? productoId = 3,
  String descripcion = 'Kit de arrastre',
  String? sku = 'KA-9021',
  double cantidad = 1,
  int precio = 60000,
}) =>
    DeudorItem(
      id: id,
      deudorId: 1,
      productoId: productoId,
      descripcion: descripcion,
      sku: sku,
      cantidad: cantidad,
      precioUnitario: precio,
    );

DeudorDetalle _deuda({
  List<DeudorItem>? items,
  List<DeudorPago> pagos = const [],
  int montoTotal = 60000,
  int montoPagado = 0,
  int descuento = 0,
  EstadoDeudor estado = EstadoDeudor.activa,
  DateTime? vence,
  String? numeroOrden,
  String? concepto,
  String? notas,
}) =>
    DeudorDetalle(
      resumen: DeudorResumen(
        id: 1,
        numero: 'DEU-0031',
        clienteId: 7,
        nombreCliente: 'José Muñoz',
        nombreMoto: 'Boxer CT 100',
        placaMoto: 'KMN12C',
        numeroOrden: numeroOrden,
        ordenId: numeroOrden == null ? null : 5,
        concepto: concepto,
        descuento: descuento,
        montoTotal: montoTotal,
        montoPagado: montoPagado,
        estado: estado,
        fechaVencimiento: vence,
        notas: notas,
        creadoEn: DateTime(2026, 8, 12),
      ),
      items: items ?? [_itemDeuda()],
      pagos: pagos,
    );

DeudorPago _pago(int monto, DateTime fecha, {String? notas}) => DeudorPago(
      id: monto,
      deudorId: 1,
      monto: monto,
      metodoPago: MetodoPago.nequi,
      notas: notas,
      fechaPago: fecha,
    );

CompraItem _itemCompra({
  int id = 1,
  String descripcion = 'Pastilla de freno',
  String? sku = 'PF-100',
  double cantidad = 10,
  int costo = 6500,
}) =>
    CompraItem(
      id: id,
      compraId: 1,
      productoId: 4,
      descripcion: descripcion,
      sku: sku,
      cantidad: cantidad,
      costoUnitario: costo,
    );

CompraDetalle _compra({
  List<CompraItem>? items,
  int total = 65000,
  EstadoCompra estado = EstadoCompra.registrada,
  String? numeroFactura = 'FV-8871',
  String? notas,
}) =>
    CompraDetalle(
      resumen: CompraResumen(
        id: 1,
        numero: 'COM-2026-0007',
        proveedorId: 2,
        proveedorNombre: 'Distribuidora del Norte',
        numeroFactura: numeroFactura,
        fecha: DateTime(2026, 8, 20),
        total: total,
        estado: estado,
        notas: notas,
        creadoEn: DateTime(2026, 8, 20),
      ),
      items: items ?? [_itemCompra()],
    );

void main() {
  group('una deuda se traduce a papel', () {
    tearDown(() => configurarIva(0));

    test('la moto identifica la cuenta, como en la reserva', () {
      final doc = documentoDeDeuda(deuda: _deuda(), negocio: _negocio);
      expect(doc.cliente, 'José Muñoz');
      expect(doc.documentoCliente, 'Boxer CT 100 · KMN12C');
    });

    test('solo repuestos: un bloque, sin título que no separa nada', () {
      final doc = documentoDeDeuda(deuda: _deuda(), negocio: _negocio);
      expect(doc.bloques, hasLength(1));
      expect(doc.bloques.single.titulo, isNull);
    });

    test('lo que no tiene producto detrás va en su propio bloque', () {
      // Una orden cerrada a crédito trae tareas y cargos sueltos: no tienen
      // catálogo, y lo que los distingue es la FK, no el texto.
      final doc = documentoDeDeuda(
        deuda: _deuda(items: [
          _itemDeuda(),
          _itemDeuda(
            id: 2,
            productoId: null,
            descripcion: 'Sincronización',
            sku: null,
            precio: 40000,
          ),
        ]),
        negocio: _negocio,
      );

      expect(doc.bloques.map((b) => b.titulo), ['Repuestos', 'Mano de obra']);
      expect(doc.bloques.last.lineas.single.referencia, isNull);
    });

    test('el saldo se imprime aunque esté en cero', () {
      // Es lo contrario que en una factura: quien viene a pedir el papel de
      // una deuda saldada viene a que diga cero.
      final doc = documentoDeDeuda(
        deuda: _deuda(montoPagado: 60000, estado: EstadoDeudor.pagada),
        negocio: _negocio,
      );
      expect(doc.saldoPendiente, 0);
    });

    test('lo que falta por cobrar sale del saldo de la deuda', () {
      final doc = documentoDeDeuda(
        deuda: _deuda(montoPagado: 20000),
        negocio: _negocio,
      );
      expect(doc.saldoPendiente, 40000);
    });

    test('los pagos van del más viejo al más nuevo, venga como venga', () {
      final doc = documentoDeDeuda(
        deuda: _deuda(pagos: [
          _pago(15000, DateTime(2026, 8, 25)),
          _pago(5000, DateTime(2026, 8, 15), notas: 'M-77812'),
        ]),
        negocio: _negocio,
      );

      expect(doc.tituloMovimientos, 'Pagos recibidos');
      expect(doc.movimientos.map((m) => m.fecha),
          [DateTime(2026, 8, 15), DateTime(2026, 8, 25)]);
      expect(doc.movimientos.first.referencia, 'M-77812');
    });

    test('el subtotal reconstruye lo de antes del descuento', () {
      // `montoTotal` ya viene rebajado, así que sumarle el descuento es lo que
      // hace que subtotal − descuento = total en el papel.
      final doc = documentoDeDeuda(
        deuda: _deuda(montoTotal: 55000, descuento: 5000),
        negocio: _negocio,
      );

      expect(doc.subtotal, 60000);
      expect(doc.descuento, 5000);
      expect(doc.total, 55000);
      expect(doc.tieneDescuento, isTrue);
    });

    test('sin tasa configurada el IVA no se imprime', () {
      final doc = documentoDeDeuda(deuda: _deuda(), negocio: _negocio);
      expect(doc.iva, isNull);
    });

    test('con tasa configurada se discrimina el IVA del total', () {
      configurarIva(19);
      final doc = documentoDeDeuda(
        deuda: _deuda(montoTotal: 119000),
        negocio: _negocio,
      );
      expect(doc.iva, 19000);
    });

    test('una deuda dada por perdida lo dice en el título', () {
      final doc = documentoDeDeuda(
        deuda: _deuda(estado: EstadoDeudor.incobrable),
        negocio: _negocio,
      );
      expect(doc.titulo, 'Cuenta dada por perdida');
    });

    test('el plazo va al pie, y dice si ya pasó', () {
      final vigente = documentoDeDeuda(
        deuda: _deuda(vence: DateTime(2099, 1, 15)),
        negocio: _negocio,
      );
      expect(vigente.nota, contains('Plazo hasta el 15/01/2099'));

      final vencida = documentoDeDeuda(
        deuda: _deuda(vence: DateTime(2020, 1, 15)),
        negocio: _negocio,
      );
      expect(vencida.nota, contains('Venció el 15/01/2020'));
    });

    test('si viene de una orden, el pie lo menciona en vez del concepto', () {
      final doc = documentoDeDeuda(
        deuda: _deuda(numeroOrden: 'ORD-0041', concepto: 'Reparación'),
        negocio: _negocio,
      );
      expect(doc.nota, contains('ORD-0041'));
      expect(doc.nota, isNot(contains('Reparación')));
    });

    test('sin orden, el concepto ocupa su lugar', () {
      final doc = documentoDeDeuda(
        deuda: _deuda(concepto: 'Reparación del motor'),
        negocio: _negocio,
      );
      expect(doc.nota, contains('Reparación del motor'));
    });
  });

  group('una compra se traduce a papel', () {
    test('el destinatario es el proveedor, y el papel lo dice', () {
      final doc = documentoDeCompra(compra: _compra(), negocio: _negocio);
      expect(doc.cliente, 'Distribuidora del Norte');
      expect(doc.etiquetaDestinatario, 'Proveedor');
      expect(doc.etiquetaAtendidoPor, 'Recibido por');
    });

    test('la factura del proveedor identifica la remisión', () {
      final doc = documentoDeCompra(compra: _compra(), negocio: _negocio);
      expect(doc.documentoCliente, 'Factura FV-8871');
    });

    test('sin factura del proveedor no se pinta un rótulo huérfano', () {
      final doc = documentoDeCompra(
        compra: _compra(numeroFactura: null),
        negocio: _negocio,
      );
      expect(doc.documentoCliente, isNull);
    });

    test('no lleva IVA: quien lo factura es el proveedor', () {
      final doc = documentoDeCompra(compra: _compra(), negocio: _negocio);
      expect(doc.iva, isNull);
    });

    test('no lleva pagos ni saldo: la cuenta con el proveedor no se modela',
        () {
      final doc = documentoDeCompra(compra: _compra(), negocio: _negocio);
      expect(doc.tieneMovimientos, isFalse);
      expect(doc.saldoPendiente, isNull);
    });

    test('la columna del precio es el costo de compra', () {
      final doc = documentoDeCompra(compra: _compra(), negocio: _negocio);
      final linea = doc.bloques.single.lineas.single;
      expect(linea.precioUnitario, 6500);
      expect(linea.cantidad, 10);
      expect(linea.subtotal, 65000);
      expect(linea.referencia, 'PF-100');
    });

    test('el subtotal suma las líneas y el total es el caché de la cabecera',
        () {
      // Si algún día dejan de coincidir, el papel lo enseña: es la misma
      // pregunta que responde `RepositorioCompras.descuadres()`.
      final doc = documentoDeCompra(compra: _compra(), negocio: _negocio);
      expect(doc.subtotal, 65000);
      expect(doc.total, 65000);
    });

    test('una remisión anulada lo dice en el título y en el pie', () {
      final doc = documentoDeCompra(
        compra: _compra(estado: EstadoCompra.anulada),
        negocio: _negocio,
      );
      expect(doc.titulo, 'Remisión anulada');
      expect(doc.nota, contains('volvió a salir del inventario'));
    });

    test('un borrador se imprime, y el pie dice que lo es', () {
      final doc = documentoDeCompra(
        compra: _compra(estado: EstadoCompra.borrador),
        negocio: _negocio,
      );
      expect(doc.titulo, 'Remisión de entrada');
      expect(doc.nota, contains('Borrador'));
    });

    test('el conteo de productos va al pie: es lo que se coteja con las cajas',
        () {
      final una = documentoDeCompra(compra: _compra(), negocio: _negocio);
      expect(una.nota, contains('1 producto ·'));

      final dos = documentoDeCompra(
        compra: _compra(items: [_itemCompra(), _itemCompra(id: 2)]),
        negocio: _negocio,
      );
      expect(dos.nota, contains('2 productos ·'));
    });

    test('las notas del taller acompañan al conteo', () {
      final doc = documentoDeCompra(
        compra: _compra(notas: 'Llegaron dos cajas golpeadas.'),
        negocio: _negocio,
      );
      expect(doc.nota, contains('Llegaron dos cajas golpeadas.'));
    });
  });

  group('los dos se convierten en un PDF de verdad', () {
    // Sin esto, cualquier cambio en las secciones podría lanzar en tiempo de
    // ejecución y no lo sabríamos hasta que una caja intentara imprimir.
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    test('la cuenta por cobrar', () async {
      final doc = documentoDeDeuda(
        deuda: _deuda(
          items: [
            _itemDeuda(),
            _itemDeuda(id: 2, productoId: null, descripcion: 'Ajuste', sku: null),
          ],
          pagos: [_pago(20000, DateTime(2026, 8, 20))],
          montoPagado: 20000,
          descuento: 5000,
          vence: DateTime(2026, 9, 30),
        ),
        negocio: _negocio,
      );

      final bytes = await const ConstructorPdf().construir(doc);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('la remisión de entrada', () async {
      final doc = documentoDeCompra(
        compra: _compra(items: [_itemCompra(), _itemCompra(id: 2)]),
        negocio: _negocio,
      );

      final bytes = await const ConstructorPdf().construir(doc);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });
}
