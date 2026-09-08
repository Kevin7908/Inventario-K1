// La factura tiene que decir quién compró, quién vendió y qué se llevó, con
// el detalle que el mostrador de verdad usa.
//
// Hasta el 07/09/2026 el impreso solo llevaba el nombre del cliente y ni
// siquiera el del cajero: no había forma de saber a quién reclamarle, ni de
// volver a pedir la misma pieza sin el código. Esto fija lo que decide qué
// aparece en el papel; el dibujo en sí no se puede afirmar con un test.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/configuracion/modelo/clave_configuracion.dart';
import 'package:inventario_k1/backend/features/pos/enum/enum_ventas.dart';
import 'package:inventario_k1/backend/features/pos/modelo/venta_detalle.dart';
import 'package:inventario_k1/backend/features/pos/modelo/venta_item.dart';
import 'package:inventario_k1/core/iva_app.dart';
import 'package:inventario_k1/frontend/features/documentos/modelo/negocio_impreso.dart';
import 'package:inventario_k1/frontend/features/documentos/traductores/venta_a_documento.dart';

const _negocio = NegocioImpreso(
  nombre: 'Taller K1',
  nit: '901.555.222-8',
  direccion: 'Cra. 8 #23-45',
  telefono: '602 555 7788',
  ciudad: 'Cali',
  correo: 'taller@k1.co',
  regimenIva: 'Responsable de IVA',
  actividadEconomica: '4530',
);

VentaItem _item({String sku = 'FRE-0012', String unidad = 'UND'}) => VentaItem(
      id: 1,
      ventaId: 1,
      tipoItem: TipoItem.producto,
      descripcion: 'Pastilla de freno',
      sku: sku,
      unidad: unidad,
      cantidad: 2,
      precioUnitario: 28000,
      costoUnitario: 15000,
      subtotal: 56000,
    );

VentaDetalle _venta({int? clienteId = 7, int iva = 0}) => VentaDetalle(
      id: 1,
      numeroFactura: 'F-000123',
      tipo: TipoVenta.mostrador,
      clienteId: clienteId,
      clienteNombre: 'Carlos Ramírez',
      clienteDocumento: 'CC 1098765432',
      clienteDireccion: 'Calle 5 #10-20',
      clienteCiudad: 'Cali',
      clienteTelefono: '3116351015',
      clienteCorreo: 'carlos@correo.com',
      subtotal: 56000,
      iva: iva,
      descuento: 0,
      total: 56000 + iva,
      totalPagado: 56000 + iva,
      metodoPago: MetodoPago.efectivo,
      estadoPago: EstadoPago.pagado,
      creadoEn: DateTime(2026, 9, 7, 15, 14),
      cajero: 'Ana Gómez',
      vendedor: 'Luis Posada',
      items: [_item()],
    );

void main() {
  group('el encabezado del negocio', () {
    test('la línea fiscal junta régimen y actividad económica', () {
      expect(
        _negocio.lineaFiscal,
        'Responsable de IVA · Actividad económica 4530',
      );
    });

    test('el correo entra en la línea de contacto', () {
      expect(_negocio.lineaContacto, contains('taller@k1.co'));
    });

    test('un taller que no cargó los datos fiscales no imprime la línea', () {
      const sinCargar = NegocioImpreso(nombre: 'Taller K1');
      expect(sinCargar.lineaFiscal, isEmpty);
    });

    test('las claves nuevas existen en la configuración', () {
      // Si alguien renombra la clave, el dato deja de aparecer sin que nada
      // falle: la tabla es clave-valor y un typo no da error, da un vacío.
      for (final clave in [
        ClaveConfiguracion.correo,
        ClaveConfiguracion.regimenIva,
        ClaveConfiguracion.actividadEconomica,
        ClaveConfiguracion.notaFactura,
      ]) {
        expect(ClaveConfiguracion.desdeClave(clave.clave), clave);
      }
    });
  });

  group('el bloque del cliente', () {
    test('lleva los cinco datos, no solo el nombre', () {
      final doc = documentoDeVenta(venta: _venta(), negocio: _negocio);
      final quien = doc.destinatario!;

      expect(quien.nombre, 'Carlos Ramírez');
      expect(quien.campos, [
        ('Documento', 'CC 1098765432'),
        ('Dirección', 'Calle 5 #10-20'),
        ('Ciudad', 'Cali'),
        ('Teléfono', '3116351015'),
        ('Correo', 'carlos@correo.com'),
      ]);
    });

    test('sin cliente identificado dice CONSUMIDOR FINAL', () {
      final doc =
          documentoDeVenta(venta: _venta(clienteId: null), negocio: _negocio);

      expect(doc.destinatario?.nombre, 'CONSUMIDOR FINAL');
      expect(doc.destinatario?.tieneDetalle, isFalse,
          reason: 'no se inventan datos de quien no se identificó');
    });
  });

  group('quién despachó', () {
    test('el cajero y el vendedor viajan por separado', () {
      final doc = documentoDeVenta(
        venta: _venta(),
        negocio: _negocio,
        atendidoPor: 'Ana Gómez',
        vendedor: 'Luis Posada',
      );

      expect(doc.atendidoPor, 'Ana Gómez');
      expect(doc.vendedor, 'Luis Posada');
    });

    test('la factura se firma; se entrega contra la mercancía', () {
      final doc = documentoDeVenta(venta: _venta(), negocio: _negocio);
      expect(doc.conFirmas, isTrue);
    });
  });

  group('las líneas', () {
    test('llevan el código y la unidad del catálogo', () {
      final doc = documentoDeVenta(venta: _venta(), negocio: _negocio);
      final linea = doc.bloques.single.lineas.single;

      expect(linea.codigo, 'FRE-0012');
      expect(linea.unidad, 'UND');
      expect(linea.tieneCodigo, isTrue);
    });

    test('un producto borrado deja la línea sin código, no sin factura', () {
      final venta = VentaDetalle(
        id: 1,
        numeroFactura: 'F-000123',
        tipo: TipoVenta.mostrador,
        clienteNombre: '— Sin cliente —',
        subtotal: 56000,
        iva: 0,
        descuento: 0,
        total: 56000,
        totalPagado: 56000,
        metodoPago: MetodoPago.efectivo,
        estadoPago: EstadoPago.pagado,
        items: [_item(sku: '', unidad: '')],
      );

      final linea =
          documentoDeVenta(venta: venta, negocio: _negocio)
              .bloques
              .single
              .lineas
              .single;

      expect(linea.codigo, isNull);
      expect(linea.tieneCodigo, isFalse);
    });
  });

  group('el renglón de IVA', () {
    tearDown(() => configurarIva(0));

    test('dice el porcentaje vigente y no «incluido»', () {
      configurarIva(19);
      final doc =
          documentoDeVenta(venta: _venta(iva: 10640), negocio: _negocio);

      expect(doc.iva, 10640);
      expect(doc.etiquetaIva, 'IVA (19%)');
      expect(doc.total, doc.subtotal + doc.iva!,
          reason: 'el impuesto se le suma a la base');
    });

    test('sin tasa configurada no se pinta', () {
      final doc = documentoDeVenta(venta: _venta(), negocio: _negocio);
      expect(doc.iva, isNull);
    });
  });

  group('el pie', () {
    test('sale la nota que el taller configuró', () {
      final doc = documentoDeVenta(
        venta: _venta(),
        negocio: _negocio,
        nota: 'No se aceptan devoluciones después de 5 días.',
      );

      expect(doc.nota, 'No se aceptan devoluciones después de 5 días.');
    });

    test('sin nota ni orden no hay pie que imprimir', () {
      final doc = documentoDeVenta(venta: _venta(), negocio: _negocio);
      expect(doc.nota, isNull);
    });
  });
}
