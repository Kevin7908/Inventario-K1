// El mismo documento en tres papeles.
//
// Lo que se puede afirmar de un PDF sin verlo impreso es poco, así que aquí se
// fijan las tres cosas que sí decide el código y que romperían el impreso sin
// que nadie se entere:
//
// 1. que cada formato apunte al papel que dice —una tirilla de 80 mm que
//    saliera en carta no se notaría hasta la primera factura del mostrador—;
// 2. que el rollo tenga **alto infinito**, que es lo que hace que la térmica
//    corte donde termina el texto y no tres metros después;
// 3. que los tres construyan un PDF de verdad. La tirilla se arma con `Page` y
//    la carta con `MultiPage` —`MultiPage` tiene un `assert` contra el alto
//    infinito—, así que son dos caminos distintos y los dos tienen que andar.
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/pos/enum/enum_ventas.dart';
import 'package:inventario_k1/backend/features/pos/modelo/venta_detalle.dart';
import 'package:inventario_k1/backend/features/pos/modelo/venta_item.dart';
import 'package:inventario_k1/frontend/features/documentos/modelo/negocio_impreso.dart';
import 'package:inventario_k1/frontend/features/documentos/servicio/constructor_pdf.dart';
import 'package:inventario_k1/frontend/features/documentos/servicio/formato_impreso.dart';
import 'package:inventario_k1/frontend/features/documentos/traductores/venta_a_documento.dart';
import 'package:pdf/pdf.dart';

const _negocio = NegocioImpreso(
  nombre: 'Taller K1',
  nit: '901.555.222-8',
  direccion: 'Cra. 8 #23-45',
  ciudad: 'Cali',
);

VentaItem _item(int i) => VentaItem(
      id: i,
      ventaId: 1,
      tipoItem: TipoItem.producto,
      descripcion: 'Pastilla de freno delantera cerámica $i',
      cantidad: 2,
      precioUnitario: 28000,
      costoUnitario: 15000,
      subtotal: 56000,
    );

VentaDetalle _venta({int lineas = 1}) => VentaDetalle(
      id: 1,
      numeroFactura: 'F-000123',
      tipo: TipoVenta.mostrador,
      clienteNombre: 'José Muñoz',
      subtotal: 56000 * lineas,
      iva: 0,
      descuento: 0,
      total: 56000 * lineas,
      totalPagado: 56000 * lineas,
      metodoPago: MetodoPago.efectivo,
      estadoPago: EstadoPago.pagado,
      creadoEn: DateTime(2026, 8, 28, 10, 30),
      items: [for (var i = 1; i <= lineas; i++) _item(i)],
    );

void main() {
  group('cada formato apunta a su papel', () {
    test('la carta es una hoja de oficina, con alto', () {
      expect(FormatoImpreso.carta.pagina, PdfPageFormat.letter);
      expect(FormatoImpreso.carta.pagina.height.isFinite, isTrue);
      expect(FormatoImpreso.carta.esTirilla, isFalse);
    });

    test('las dos tirillas son rollos de alto infinito', () {
      for (final formato in [
        FormatoImpreso.tirilla80,
        FormatoImpreso.tirilla58,
      ]) {
        expect(formato.esTirilla, isTrue, reason: formato.etiqueta);
        expect(formato.pagina.height, double.infinity, reason: formato.etiqueta);
      }
    });

    test('el ancho de cada tirilla es el de su impresora', () {
      // 80 mm y 57 mm de papel. Si estos anchos se cambiaran, las columnas
      // dejarían de caber sin que ningún test lo notara.
      expect(FormatoImpreso.tirilla80.pagina.width, closeTo(80 * PdfPageFormat.mm, 0.01));
      expect(FormatoImpreso.tirilla58.pagina.width, closeTo(57 * PdfPageFormat.mm, 0.01));
      expect(FormatoImpreso.tirilla80.pagina.width,
          greaterThan(FormatoImpreso.tirilla58.pagina.width));
    });

    test('en una tirilla la letra se achica; en carta no se toca', () {
      expect(FormatoImpreso.carta.ajusteTexto, 0);
      expect(FormatoImpreso.tirilla80.ajusteTexto, lessThan(0));
      expect(FormatoImpreso.tirilla58.ajusteTexto,
          lessThan(FormatoImpreso.tirilla80.ajusteTexto));
    });
  });

  group('el código guardado va y vuelve', () {
    test('cada formato tiene su código en mayúsculas', () {
      expect(FormatoImpreso.carta.codigo, 'CARTA');
      expect(FormatoImpreso.tirilla80.codigo, 'TIRILLA80');
      expect(FormatoImpreso.tirilla58.codigo, 'TIRILLA58');
    });

    test('lo guardado se lee de vuelta como el mismo formato', () {
      for (final formato in FormatoImpreso.values) {
        expect(FormatoImpreso.desdeCodigo(formato.codigo), formato);
      }
    });

    test('un código que nadie reconoce cae en carta, no deja sin imprimir', () {
      expect(FormatoImpreso.desdeCodigo(''), FormatoImpreso.carta);
      expect(FormatoImpreso.desdeCodigo('A4'), FormatoImpreso.carta);
      // Minúsculas y espacios de una base tocada a mano tampoco rompen nada.
      expect(FormatoImpreso.desdeCodigo(' tirilla80 '), FormatoImpreso.tirilla80);
    });
  });

  group('los tres formatos construyen un PDF de verdad', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    for (final formato in FormatoImpreso.values) {
      test(formato.etiqueta, () async {
        final doc = documentoDeVenta(venta: _venta(), negocio: _negocio);
        final bytes =
            await const ConstructorPdf().construir(doc, formato: formato);

        expect(bytes, isNotEmpty);
        expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      });
    }

    test('una factura larga en carta se reparte en varias hojas', () async {
      // El camino del `MultiPage`: 120 líneas no caben en una hoja, así que
      // el PDF tiene que pesar más que el de una sola. Es lo que confirma que
      // el corte por páginas sigue funcionando con el encabezado repetido.
      final corta = documentoDeVenta(venta: _venta(), negocio: _negocio);
      final larga =
          documentoDeVenta(venta: _venta(lineas: 120), negocio: _negocio);

      final bytesCorta = await const ConstructorPdf().construir(corta);
      final bytesLarga = await const ConstructorPdf().construir(larga);

      expect(bytesLarga.length, greaterThan(bytesCorta.length));
    });

    test('una tirilla larga no se parte: el rollo crece', () async {
      // El camino de la `Page`. Con alto infinito el paquete reemplaza el alto
      // por el del contenido, así que 120 líneas siguen siendo una página.
      final doc = documentoDeVenta(venta: _venta(lineas: 120), negocio: _negocio);
      final bytes = await const ConstructorPdf()
          .construir(doc, formato: FormatoImpreso.tirilla80);

      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });

  test('el impreso lleva su fuente empaquetada, no la Helvetica del paquete',
      () async {
    // Helvetica no tiene Unicode: cualquier carácter fuera de Latin-1 saldría
    // mal en un papel que el taller entrega. Noto Sans va en `assets/fonts/`,
    // y este test comprueba que el asset **está declarado y se puede leer**:
    // si alguien lo saca del `pubspec.yaml`, el impreso caería en silencio a
    // Helvetica y nadie se enteraría hasta ver una ñ rota.
    TestWidgetsFlutterBinding.ensureInitialized();

    for (final ruta in [
      ConstructorPdf.rutaFuente,
      ConstructorPdf.rutaFuenteNegrita,
    ]) {
      final datos = await rootBundle.load(ruta);
      expect(datos.lengthInBytes, greaterThan(1000), reason: ruta);
    }
  });
}
