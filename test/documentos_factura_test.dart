// Lo que se prueba aquí es la **traducción**, no el dibujo.
//
// El PDF en sí no se puede afirmar con un test —que un renglón quede a 240 pt
// del margen no lo sabe nadie hasta verlo impreso—, pero sí se puede fijar lo
// que decide qué aparece en el papel: cuándo se esconde el IVA, cuándo el
// saldo, cuándo los bloques llevan título. Esas son las reglas que se
// romperían sin que nadie se entere.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/configuracion/modelo/clave_configuracion.dart';
import 'package:inventario_k1/backend/features/pos/enum/enum_ventas.dart';
import 'package:inventario_k1/backend/features/pos/modelo/venta_detalle.dart';
import 'package:inventario_k1/backend/features/pos/modelo/venta_item.dart';
import 'package:inventario_k1/backend/features/reservas/enum/enum_reserva.dart';
import 'package:inventario_k1/backend/features/reservas/modelo/reserva_abono.dart';
import 'package:inventario_k1/backend/features/reservas/modelo/reserva_detalle.dart';
import 'package:inventario_k1/backend/features/reservas/modelo/reserva_item.dart';
import 'package:inventario_k1/backend/features/reservas/modelo/reserva_resumen.dart';
import 'package:inventario_k1/frontend/features/documentos/modelo/negocio_impreso.dart';
import 'package:inventario_k1/frontend/features/documentos/servicio/constructor_pdf.dart';
import 'package:inventario_k1/frontend/features/documentos/traductores/reserva_a_documento.dart';
import 'package:inventario_k1/frontend/features/documentos/traductores/venta_a_documento.dart';

const _negocio = NegocioImpreso(
  nombre: 'Taller K1',
  nit: '901.555.222-8',
  direccion: 'Cra. 8 #23-45',
  telefono: '602 555 7788',
  ciudad: 'Cali',
);

VentaItem _item({
  TipoItem tipo = TipoItem.producto,
  String descripcion = 'Pastilla de freno',
  int precio = 28000,
}) =>
    VentaItem(
      id: 1,
      ventaId: 1,
      tipoItem: tipo,
      descripcion: descripcion,
      cantidad: 1,
      precioUnitario: precio,
      costoUnitario: 15000,
      subtotal: precio,
    );

VentaDetalle _venta({
  List<VentaItem>? items,
  int iva = 0,
  int descuento = 0,
  int total = 28000,
  int totalPagado = 28000,
  EstadoPago estado = EstadoPago.pagado,
  String? numeroOrden,
}) =>
    VentaDetalle(
      id: 1,
      numeroFactura: 'F-000123',
      tipo: TipoVenta.mostrador,
      numeroOrden: numeroOrden,
      clienteNombre: 'Consumidor final',
      subtotal: 28000,
      iva: iva,
      descuento: descuento,
      total: total,
      totalPagado: totalPagado,
      metodoPago: MetodoPago.efectivo,
      estadoPago: estado,
      creadoEn: DateTime(2026, 8, 28, 10, 30),
      items: items ?? [_item()],
    );

void main() {
  group('el encabezado del taller sale de la configuración', () {
    test('junta dirección y ciudad, y NIT y teléfono', () {
      expect(_negocio.lineaUbicacion, 'Cra. 8 #23-45 · Cali');
      expect(_negocio.lineaContacto, 'NIT 901.555.222-8 · Tel. 602 555 7788');
    });

    test('un dato que falta no deja el separador suelto', () {
      const soloCiudad = NegocioImpreso(nombre: 'Taller K1', ciudad: 'Cali');
      expect(soloCiudad.lineaUbicacion, 'Cali');
      expect(soloCiudad.lineaContacto, isEmpty);
    });

    test('sin nada configurado usa los valores por defecto de las claves', () {
      final negocio = NegocioImpreso.desdeConfiguracion(const {});
      expect(negocio.nombre, ClaveConfiguracion.nombreNegocio.porDefecto);
      expect(negocio.nit, isEmpty);
    });
  });

  group('una venta se traduce a papel', () {
    test('el IVA en cero no se imprime', () {
      final doc = documentoDeVenta(venta: _venta(), negocio: _negocio);
      expect(doc.iva, isNull);
    });

    test('el IVA se imprime cuando el documento lo guardó', () {
      final doc =
          documentoDeVenta(venta: _venta(iva: 4471), negocio: _negocio);
      expect(doc.iva, 4471);
    });

    test('una factura pagada no imprime saldo pendiente', () {
      final doc = documentoDeVenta(venta: _venta(), negocio: _negocio);
      expect(doc.saldoPendiente, isNull);
    });

    test('si queda saldo, se imprime', () {
      final doc = documentoDeVenta(
        venta: _venta(totalPagado: 10000, estado: EstadoPago.pendiente),
        negocio: _negocio,
      );
      expect(doc.saldoPendiente, 18000);
    });

    test('solo productos: un bloque, sin título que no separa nada', () {
      final doc = documentoDeVenta(venta: _venta(), negocio: _negocio);
      expect(doc.bloques, hasLength(1));
      expect(doc.bloques.single.titulo, isNull);
    });

    test('productos y servicios: dos bloques titulados', () {
      final doc = documentoDeVenta(
        venta: _venta(items: [
          _item(),
          _item(tipo: TipoItem.servicio, descripcion: 'Sincronización'),
        ]),
        negocio: _negocio,
      );
      expect(doc.bloques.map((b) => b.titulo),
          ['Repuestos', 'Mano de obra']);
    });

    test('la forma de pago va como un movimiento, con su propio rótulo', () {
      final doc = documentoDeVenta(venta: _venta(), negocio: _negocio);
      expect(doc.tituloMovimientos, 'Pago recibido');
      expect(doc.movimientos.single.concepto, 'Efectivo');
      expect(doc.movimientos.single.monto, 28000);
    });

    test('una venta anulada lo dice en el título', () {
      final doc = documentoDeVenta(
        venta: _venta(estado: EstadoPago.anulada),
        negocio: _negocio,
      );
      expect(doc.titulo, 'Factura anulada');
    });

    test('si viene de una orden, el pie lo menciona', () {
      final doc = documentoDeVenta(
        venta: _venta(numeroOrden: 'OS-0042'),
        negocio: _negocio,
      );
      expect(doc.nota, contains('OS-0042'));
    });
  });

  group('una reserva imprime lo abonado y lo que falta', () {
    ReservaDetalle reserva({
      List<ReservaAbono> abonos = const [],
      int total = 100000,
      int pagado = 40000,
      DateTime? limite,
    }) =>
        ReservaDetalle(
          resumen: ReservaResumen(
            id: 1,
            numero: 'R-000045',
            clienteId: 7,
            nombreCliente: 'José Muñoz',
            nombreMoto: 'Boxer CT 100',
            placaMoto: 'KMN12C',
            estado: EstadoReserva.activa,
            totalReserva: total,
            pagadoAcumulado: pagado,
            creadoEn: DateTime(2026, 8, 1),
            fechaLimite: limite,
          ),
          items: const [
            ReservaItem(
              id: 1,
              reservaId: 1,
              productoId: 3,
              nombreProducto: 'Kit de arrastre',
              sku: 'KA-9021',
              cantidad: 2,
              precioUnitario: 50000,
            ),
          ],
          abonos: abonos,
        );

    ReservaAbono abono(int monto, DateTime fecha, {String? referencia}) =>
        ReservaAbono(
          id: monto,
          reservaId: 1,
          monto: monto,
          metodoPago: MetodoPago.nequi,
          referenciaPago: referencia,
          fechaPago: fecha,
        );

    test('lista cada abono con su fecha y su monto', () {
      final doc = documentoDeReserva(
        reserva: reserva(abonos: [
          abono(25000, DateTime(2026, 8, 10)),
          abono(15000, DateTime(2026, 8, 20), referencia: 'M-77812'),
        ]),
        negocio: _negocio,
      );

      expect(doc.tituloMovimientos, 'Abonos recibidos');
      expect(doc.movimientos, hasLength(2));
      expect(doc.movimientos.first.monto, 25000);
      expect(doc.movimientos.last.referencia, 'M-77812');
    });

    test('los ordena del más viejo al más nuevo, venga como venga', () {
      final doc = documentoDeReserva(
        reserva: reserva(abonos: [
          abono(15000, DateTime(2026, 8, 20)),
          abono(25000, DateTime(2026, 8, 10)),
        ]),
        negocio: _negocio,
      );

      expect(doc.movimientos.map((m) => m.fecha),
          [DateTime(2026, 8, 10), DateTime(2026, 8, 20)]);
    });

    test('lo que falta por pagar sale del saldo de la reserva', () {
      final doc = documentoDeReserva(reserva: reserva(), negocio: _negocio);
      expect(doc.saldoPendiente, 60000);
    });

    test('una reserva pagada imprime el saldo en cero, que es la noticia', () {
      final doc = documentoDeReserva(
        reserva: reserva(pagado: 100000),
        negocio: _negocio,
      );
      expect(doc.saldoPendiente, 0);
    });

    test('una devolución se marca como tal y no se esconde', () {
      final doc = documentoDeReserva(
        reserva: reserva(abonos: [
          abono(25000, DateTime(2026, 8, 10)),
          abono(-5000, DateTime(2026, 8, 15)),
        ]),
        negocio: _negocio,
      );
      expect(doc.movimientos.last.esDevolucion, isTrue);
    });

    test('la moto identifica la reserva, no la cédula', () {
      final doc = documentoDeReserva(reserva: reserva(), negocio: _negocio);
      expect(doc.documentoCliente, 'Boxer CT 100 · KMN12C');
    });

    test('la vigencia va al pie cuando la reserva tiene fecha límite', () {
      final doc = documentoDeReserva(
        reserva: reserva(limite: DateTime(2026, 9, 15)),
        negocio: _negocio,
      );
      expect(doc.nota, contains('15/09/2026'));
    });

    test('el SKU acompaña a la línea', () {
      final doc = documentoDeReserva(reserva: reserva(), negocio: _negocio);
      expect(doc.bloques.single.lineas.single.referencia, 'KA-9021');
      expect(doc.bloques.single.lineas.single.subtotal, 100000);
    });
  });

  test('el documento se convierte en un PDF de verdad', () async {
    // Sin esto, cualquier cambio en las secciones podría lanzar en tiempo de
    // ejecución y no lo sabríamos hasta que una caja intentara imprimir.
    TestWidgetsFlutterBinding.ensureInitialized();
    final doc = documentoDeVenta(
      venta: _venta(items: [
        _item(),
        _item(tipo: TipoItem.servicio, descripcion: 'Sincronización'),
      ], iva: 4471, descuento: 2000),
      negocio: _negocio,
    );

    final bytes = await const ConstructorPdf().construir(doc);

    expect(bytes, isNotEmpty);
    // Todo PDF empieza por «%PDF».
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
