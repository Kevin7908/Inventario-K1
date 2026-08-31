// Los otros dos documentos que emite el taller: la cotización y la orden.
//
// Se prueba la traducción —qué acaba en el papel— por lo mismo que en la
// factura: el dibujo no se puede afirmar con un test, pero las reglas de qué
// aparece y qué se omite sí, y son las que se rompen sin que nadie lo note.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/cotizaciones/enum/enum_cotizacion.dart';
import 'package:inventario_k1/backend/features/cotizaciones/modelo/cotizacion_detalle.dart';
import 'package:inventario_k1/backend/features/cotizaciones/modelo/cotizacion_item.dart';
import 'package:inventario_k1/backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import 'package:inventario_k1/backend/features/ordenes/enum/enum_ordenes.dart';
import 'package:inventario_k1/backend/features/ordenes/modelo/orden_cargo.dart';
import 'package:inventario_k1/backend/features/ordenes/modelo/orden_detalle.dart';
import 'package:inventario_k1/backend/features/ordenes/modelo/orden_repuesto.dart';
import 'package:inventario_k1/backend/features/ordenes/modelo/orden_tarea.dart';
import 'package:inventario_k1/frontend/features/documentos/modelo/negocio_impreso.dart';
import 'package:inventario_k1/frontend/features/documentos/servicio/constructor_pdf.dart';
import 'package:inventario_k1/frontend/features/documentos/traductores/cotizacion_a_documento.dart';
import 'package:inventario_k1/frontend/features/documentos/traductores/orden_a_documento.dart';

const _negocio = NegocioImpreso(nombre: 'Taller K1', ciudad: 'Cali');

CotizacionItem _itemCot(
  TipoItemCotizacion tipo,
  String descripcion, {
  int precio = 30000,
}) =>
    CotizacionItem(
      id: 1,
      cotizacionId: 1,
      tipoItem: tipo,
      descripcion: descripcion,
      cantidad: 1,
      precioUnitario: precio,
      subtotal: precio,
    );

CotizacionDetalle _cotizacion({
  List<CotizacionItem>? items,
  int iva = 0,
  int descuento = 0,
  String? notas,
}) =>
    CotizacionDetalle(
      resumen: CotizacionResumen(
        id: 1,
        numero: 'C-000012',
        nombreCliente: 'José Muñoz',
        nombreMoto: 'Boxer CT 100',
        subtotal: 30000,
        descuento: descuento,
        iva: iva,
        vigenciaHasta: DateTime(2026, 9, 15),
        notas: notas,
        creadoEn: DateTime(2026, 8, 20),
      ),
      items: items ?? [_itemCot(TipoItemCotizacion.producto, 'Kit de arrastre')],
    );

OrdenDetalle _orden({
  List<OrdenTarea> tareas = const [],
  List<OrdenRepuesto> repuestos = const [],
  List<OrdenCargo> cargos = const [],
  int kilometraje = 24500,
  String? diagnostico = 'Ruido en la cadena',
}) =>
    OrdenDetalle(
      id: 1,
      numeroOrden: 'OS-0042',
      motoId: 3,
      motoDescripcion: 'Boxer CT 100',
      motoPlaca: 'KMN12C',
      clienteId: 7,
      clienteNombre: 'José Muñoz',
      kilometrajeEntrada: kilometraje,
      diagnosticoCliente: diagnostico,
      observacionesMecanico: null,
      estado: EstadoOrden.lista,
      fechaIngreso: DateTime(2026, 8, 22),
      fechaSalida: null,
      tareas: tareas,
      repuestos: repuestos,
      cargos: cargos,
    );

void main() {
  group('la cotización es una promesa con fecha', () {
    test('la vigencia va siempre al pie', () {
      final doc =
          documentoDeCotizacion(cotizacion: _cotizacion(), negocio: _negocio);
      expect(doc.titulo, 'Cotización');
      expect(doc.nota, contains('15/09/2026'));
    });

    test('las notas del vendedor se imprimen detrás de la vigencia', () {
      final doc = documentoDeCotizacion(
        cotizacion: _cotizacion(notas: 'No incluye desmonte.'),
        negocio: _negocio,
      );
      expect(doc.nota, contains('No incluye desmonte.'));
    });

    test('no lleva pagos ni saldo: todavía no se ha cobrado nada', () {
      final doc =
          documentoDeCotizacion(cotizacion: _cotizacion(), negocio: _negocio);
      expect(doc.movimientos, isEmpty);
      expect(doc.saldoPendiente, isNull);
    });

    test('con productos y servicios, dos bloques titulados', () {
      final doc = documentoDeCotizacion(
        cotizacion: _cotizacion(items: [
          _itemCot(TipoItemCotizacion.producto, 'Kit de arrastre'),
          _itemCot(TipoItemCotizacion.servicio, 'Montaje'),
        ]),
        negocio: _negocio,
      );
      expect(doc.bloques.map((b) => b.titulo), ['Repuestos', 'Mano de obra']);
    });

    test('la línea libre cuenta como mano de obra, no como repuesto', () {
      final doc = documentoDeCotizacion(
        cotizacion: _cotizacion(
          items: [_itemCot(TipoItemCotizacion.libre, 'Ajuste varios')],
        ),
        negocio: _negocio,
      );
      expect(doc.bloques, hasLength(1));
      expect(doc.bloques.single.lineas.single.descripcion, 'Ajuste varios');
    });

    test('el IVA en cero no se imprime', () {
      expect(
        documentoDeCotizacion(cotizacion: _cotizacion(), negocio: _negocio).iva,
        isNull,
      );
      expect(
        documentoDeCotizacion(
                cotizacion: _cotizacion(iva: 4790), negocio: _negocio)
            .iva,
        4790,
      );
    });
  });

  group('la orden de servicio separa trabajo de piezas', () {
    final tarea = const OrdenTarea(
      id: 1,
      ordenId: 1,
      servicioId: 2,
      tecnicoId: 4,
      servicioNombre: 'Sincronización',
      tecnicoNombre: 'Andrés Rojas',
      precioPactado: 45000,
      completado: true,
    );
    const repuesto = OrdenRepuesto(
      id: 1,
      ordenId: 1,
      productoId: 3,
      productoNombre: 'Kit de arrastre',
      cantidad: 1,
      precioUnitario: 90000,
      costoUnitario: 50000,
    );
    const cargo =
        OrdenCargo(id: 1, ordenId: 1, descripcion: 'Lavado', precio: 12000);

    test('los tres grupos se titulan aunque haya uno solo', () {
      final doc = documentoDeOrden(
        orden: _orden(tareas: [tarea]),
        negocio: _negocio,
      );
      // En una orden el cliente tiene que distinguir trabajo de pieza aunque
      // solo haya de uno; en la factura de venta, al revés.
      expect(doc.bloques.single.titulo, 'Mano de obra');
    });

    test('con los tres, salen en orden: trabajo, piezas y otros', () {
      final doc = documentoDeOrden(
        orden: _orden(tareas: [tarea], repuestos: [repuesto], cargos: [cargo]),
        negocio: _negocio,
      );
      expect(doc.bloques.map((b) => b.titulo),
          ['Mano de obra', 'Repuestos', 'Otros cargos']);
      expect(doc.total, 147000);
    });

    test('la mano de obra dice qué técnico la hizo', () {
      final doc =
          documentoDeOrden(orden: _orden(tareas: [tarea]), negocio: _negocio);
      expect(doc.bloques.single.lineas.single.referencia,
          'Técnico: Andrés Rojas');
    });

    test('la moto con su placa identifica la orden', () {
      final doc = documentoDeOrden(orden: _orden(), negocio: _negocio);
      expect(doc.documentoCliente, 'Boxer CT 100 · KMN12C');
    });

    test('el kilometraje y el diagnóstico van al pie', () {
      final doc = documentoDeOrden(orden: _orden(), negocio: _negocio);
      expect(doc.nota, contains('24500 km'));
      expect(doc.nota, contains('Ruido en la cadena'));
    });

    test('sin kilometraje ni diagnóstico, el pie no queda a medias', () {
      final doc = documentoDeOrden(
        orden: _orden(kilometraje: 0, diagnostico: null),
        negocio: _negocio,
      );
      expect(doc.nota, isNull);
    });

    test('las dos se convierten en PDF de verdad', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const constructor = ConstructorPdf();

      final cotizacion = await constructor.construir(
          documentoDeCotizacion(cotizacion: _cotizacion(), negocio: _negocio));
      final orden = await constructor.construir(documentoDeOrden(
        orden: _orden(tareas: [tarea], repuestos: [repuesto], cargos: [cargo]),
        negocio: _negocio,
      ));

      expect(String.fromCharCodes(cotizacion.take(4)), '%PDF');
      expect(String.fromCharCodes(orden.take(4)), '%PDF');
    });
  });
}
