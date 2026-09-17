// Compras: la remisión del proveedor.
//
// Se escribe como una orden y no como una factura —la cabecera primero y las
// líneas de a una—, así que lo que hay que probar es lo de todo editor que
// mueve inventario: que cada línea entre con su movimiento, que cambiarla
// mueva **solo la diferencia**, que quitarla saque lo que había metido y que
// el total sea siempre la suma de lo guardado.
//
// Y lo propio de este módulo: que el costo real llegue a
// `productos.precio_compra`, que es lo que hacía que el margen de la app fuera
// el de un número tecleado una vez.
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/compras/enum/enum_compras.dart';
import 'package:inventario_k1/backend/features/compras/mapper/compra_mapper.dart';
import 'package:inventario_k1/backend/features/compras/modelo/compra_item.dart';
import 'package:inventario_k1/backend/features/compras/repositorio/repositorio_compras.dart';
import 'package:inventario_k1/backend/features/compras/repositorio/repositorio_compras_impl.dart';
import 'package:inventario_k1/backend/features/compras/resultado/resultado_compra.dart';
import 'package:inventario_k1/backend/features/inventario/repositorio/repositorio_inventario_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/permiso.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';
import 'package:inventario_k1/core/resultado.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/datos_taller.dart';
import 'soporte/sesion_de_prueba.dart';

late AppDb db;
late SesionActual sesion;
late RepositorioComprasImpl compras;
late RepositorioInventarioImpl inventario;
late DatosTaller taller;
late int proveedorId;

/// Un proveedor con su persona detrás: el nombre vive en `personas`.
Future<int> _proveedor({String nombre = 'Repuestos JR'}) async {
  final personaId = await db
      .into(db.tablaPersona)
      .insert(TablaPersonaCompanion.insert(nombres: nombre));
  return db
      .into(db.tablaProveedor)
      .insert(TablaProveedorCompanion.insert(personaId: personaId));
}

/// Una remisión con una línea anotada y **dada por terminada**, que es como
/// queda al salir del editor. [cantidad] a [costo] es el total.
///
/// Con [terminada] en `false` se queda en borrador, que es el único estado que
/// admite más cambios.
Future<ResultadoCompra> _compra({
  double cantidad = 12,
  int costo = 6500,
  String? factura = 'FV-2291',
  int? deProveedor,
  bool terminada = true,
}) async {
  final abierta = await compras.crear(
    proveedorId: deProveedor ?? proveedorId,
    numeroFactura: factura,
  );
  if (abierta is! CompraAbierta) return abierta;

  final linea = await compras.agregarLinea(
    compraId: abierta.compraId,
    productoId: taller.productoId,
    cantidad: cantidad,
    costoUnitario: costo,
  );
  expect(linea, isA<Exito>(), reason: 'la línea de partida tiene que entrar');

  if (terminada) {
    expect(await compras.terminar(abierta.compraId), isA<Exito>());
  }
  return abierta;
}

/// La única línea de la remisión.
Future<CompraItem> _linea(int compraId) async =>
    (await compras.obtenerDetalle(compraId)).items.single;

Future<double> _stock() async {
  final fila = await db
      .customSelect('SELECT stock_actual AS s FROM productos WHERE id = ?',
          variables: [Variable.withInt(taller.productoId)])
      .getSingle();
  return fila.read<double>('s');
}

Future<int> _precioCompra() async {
  final fila = await db
      .customSelect('SELECT precio_compra AS p FROM productos WHERE id = ?',
          variables: [Variable.withInt(taller.productoId)])
      .getSingle();
  return fila.read<int>('p');
}

void main() {
  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
    compras = RepositorioComprasImpl(db, sesion);
    inventario = RepositorioInventarioImpl(db, sesion);
    taller = await sembrarTaller(db, stockInicial: 10);
    proveedorId = await _proveedor();
  });

  tearDown(() => db.close());

  group('registrar una compra mete la mercancía con su documento', () {
    test('el stock sube y el movimiento apunta a la remisión', () async {
      final r = await _compra(cantidad: 12) as CompraAbierta;

      expect(await _stock(), 22);

      final movimiento = await db.customSelect(
        'SELECT tipo, cantidad, compra_id FROM movimientos_inventario '
        'WHERE compra_id = ?',
        variables: [Variable.withInt(r.compraId)],
      ).getSingle();

      expect(movimiento.read<String>('tipo'), 'ENTRADA_COMPRA');
      expect(movimiento.read<double>('cantidad'), 12);
      expect(await inventario.descuadres(), isEmpty);
    });

    test('el número sale del consecutivo, no del id', () async {
      final primera = await _compra(factura: 'FV-1') as CompraAbierta;
      final segunda = await _compra(factura: 'FV-2') as CompraAbierta;

      expect(primera.numero, endsWith('-0001'));
      expect(segunda.numero, endsWith('-0002'));
      expect(primera.numero, startsWith('COM-'));
    });

    test('el total es la suma de las líneas, no lo que diga la vista',
        () async {
      final r = await _compra(cantidad: 12, costo: 6500) as CompraAbierta;

      final detalle = await compras.obtenerDetalle(r.compraId);
      expect(detalle.resumen.total, 78000);
      expect(detalle.suma, 78000);
      expect(await compras.descuadres(), isEmpty);
    });

    test('la descripción de la línea se congela con el nombre del día',
        () async {
      final r = await _compra() as CompraAbierta;
      await db.customStatement(
        "UPDATE productos SET nombre = 'Pastilla ECO' WHERE id = "
        '${taller.productoId}',
      );

      final detalle = await compras.obtenerDetalle(r.compraId);
      expect(detalle.items.single.descripcion, 'Pastilla de freno');
      expect(detalle.items.single.sku, 'FRE-1',
          reason: 'el SKU sí es el de hoy: sirve para buscarlo');
    });

    test('el mismo producto dos veces se suma a su línea, no abre otra',
        () async {
      final r = await _compra(cantidad: 5, costo: 6000, terminada: false)
          as CompraAbierta;

      await compras.agregarLinea(
        compraId: r.compraId,
        productoId: taller.productoId,
        cantidad: 3,
        costoUnitario: 6500,
      );

      final detalle = await compras.obtenerDetalle(r.compraId);
      expect(detalle.items, hasLength(1));
      expect(detalle.items.single.cantidad, 8);
      expect(detalle.items.single.costoUnitario, 6500,
          reason: 'manda el último costo tecleado');
      expect(await _stock(), 18, reason: 'entraron las dos veces');
    });
  });

  group('la remisión se corrige línea a línea', () {
    // Todo este grupo trabaja sobre **borradores**: una remisión terminada se
    // cierra a cambios, y eso lo prueba el grupo siguiente.
    test('subir la cantidad mete solo la diferencia', () async {
      final r = await _compra(cantidad: 5, costo: 6000, terminada: false)
          as CompraAbierta;
      expect(await _stock(), 15);

      await compras.actualizarLinea((await _linea(r.compraId)).id,
          cantidad: 8);

      expect(await _stock(), 18, reason: 'entraron tres más, no ocho');
      expect((await compras.obtenerDetalle(r.compraId)).resumen.total, 48000);
      expect(await inventario.descuadres(), isEmpty);
    });

    test('bajar la cantidad saca solo la diferencia', () async {
      final r = await _compra(cantidad: 5, costo: 6000, terminada: false)
          as CompraAbierta;

      await compras.actualizarLinea((await _linea(r.compraId)).id,
          cantidad: 2);

      expect(await _stock(), 12, reason: 'salieron tres');
      expect((await compras.obtenerDetalle(r.compraId)).resumen.total, 12000);
    });

    test('bajar más de lo que queda en bodega se rechaza', () async {
      // La mercancía ya se vendió: deshacer la entrada dejaría el inventario
      // en negativo.
      final r = await _compra(cantidad: 12, terminada: false) as CompraAbierta;
      await db.customStatement(
        'UPDATE productos SET stock_actual = 3 WHERE id = ${taller.productoId}',
      );

      final resultado = await compras
          .actualizarLinea((await _linea(r.compraId)).id, cantidad: 1);

      expect(resultado, isA<Fallo>());
      expect((resultado as Fallo).mensaje, contains('ya salió del taller'));
      expect((await _linea(r.compraId)).cantidad, 12,
          reason: 'la línea se quedó como estaba');
    });

    test('cambiar el costo no mueve stock y actualiza el del producto',
        () async {
      final r = await _compra(cantidad: 5, costo: 6000, terminada: false)
          as CompraAbierta;

      await compras.actualizarLinea((await _linea(r.compraId)).id,
          costoUnitario: 7000);

      expect(await _stock(), 15);
      expect(await _precioCompra(), 7000);
      expect((await compras.obtenerDetalle(r.compraId)).resumen.total, 35000);
      expect(await compras.descuadres(), isEmpty);
    });

    test('quitar la línea saca lo que había metido', () async {
      final r = await _compra(cantidad: 12, terminada: false) as CompraAbierta;

      await compras.eliminarLinea((await _linea(r.compraId)).id);

      expect(await _stock(), 10);
      final detalle = await compras.obtenerDetalle(r.compraId);
      expect(detalle.items, isEmpty);
      expect(detalle.resumen.total, 0);
      expect(await inventario.descuadres(), isEmpty);
    });

    test('la cabecera se puede corregir sin tocar las líneas', () async {
      final r = await _compra(factura: 'FV-1', terminada: false)
          as CompraAbierta;
      final otro = await _proveedor(nombre: 'Motopartes del Sur');

      final resultado = await compras.actualizarCabecera(
        id: r.compraId,
        proveedorId: otro,
        numeroFactura: 'FV-9',
        notas: 'La trajo el mensajero',
      );

      expect(resultado, isA<Exito>());
      final detalle = await compras.obtenerDetalle(r.compraId);
      expect(detalle.resumen.proveedorNombre, 'Motopartes del Sur');
      expect(detalle.resumen.numeroFactura, 'FV-9');
      expect(detalle.items, hasLength(1));
      expect(await _stock(), 22, reason: 'la cabecera no mueve inventario');
    });

    test('la cabecera no puede quedar con una factura ya usada', () async {
      await _compra(factura: 'FV-1');
      final segunda = await _compra(factura: 'FV-2') as CompraAbierta;

      final resultado = await compras.actualizarCabecera(
        id: segunda.compraId,
        numeroFactura: 'FV-1',
      );

      expect(resultado, isA<Fallo>());
      expect((resultado as Fallo).motivo, MotivoFallo.remisionDuplicada);
    });

  });

  group('el borrador se termina o se descarta', () {
    test('el INSERT lleva el estado escrito, no heredado del DEFAULT',
        () async {
      // Se mira el `Companion` y no la fila guardada a propósito: contra una
      // base recién creada el `DEFAULT` ya es BORRADOR, así que leerla de
      // vuelta daría verde con o sin el arreglo. Lo que falló en la práctica
      // fue una base **vieja**, hecha cuando el `DEFAULT` era REGISTRADA: ahí
      // la app daba de alta remisiones ya terminadas y desde el código no
      // había forma de verlo.
      final companion = CompraMapper.nuevaACompanion(
        usuarioId: sesion.usuarioId,
        numero: 'COM-0001',
        proveedorId: proveedorId,
        fecha: DateTime(2026, 9, 1),
      );

      expect(companion.estado.present, isTrue,
          reason: 'sin esto el estado lo pone la columna, no el código');
      expect(companion.estado.value, EstadoCompra.borrador.codigo);
    });

    test('y la remisión recién abierta está en BORRADOR', () async {
      final abierta = await compras.crear(proveedorId: proveedorId);
      final detalle =
          await compras.obtenerDetalle((abierta as CompraAbierta).compraId);

      expect(detalle.resumen.estado, EstadoCompra.borrador);
    });

    test('nace en borrador y no cuenta como gasto del mes', () async {
      // Su mercancía ya está en el inventario, pero falta que quien recibe
      // diga que está todo: hasta entonces no es un gasto ni es la última
      // compra de nada.
      final r = await _compra(terminada: false) as CompraAbierta;

      final detalle = await compras.obtenerDetalle(r.compraId);
      expect(detalle.resumen.estado, EstadoCompra.borrador);
      expect(await _stock(), 22, reason: 'la mercancía sí entró');

      final resumen = await compras.observarResumen().first;
      expect(resumen.comprasMes, 0);
      expect(resumen.invertidoMes, 0);
      expect(await compras.observarUltimaCompra(taller.productoId).first,
          isNull);
    });

    test('terminarla la cierra a cambios', () async {
      final r = await _compra() as CompraAbierta;

      final resultado = await compras.agregarLinea(
        compraId: r.compraId,
        productoId: taller.productoId,
        cantidad: 1,
        costoUnitario: 100,
      );

      expect(resultado, isA<Fallo>());
      expect((resultado as Fallo).mensaje, contains('registrada'));
      expect(await _stock(), 22, reason: 'y no entró nada');
    });

    test('la guarda de la base lo impide aunque se escriba a mano', () async {
      // El repositorio da el mensaje; la base cierra la puerta (§3.4).
      final r = await _compra() as CompraAbierta;

      expect(
        () => db.into(db.tablaCompraDetalle).insert(
              TablaCompraDetalleCompanion.insert(
                compraId: r.compraId,
                productoId: taller.productoId,
                descripcion: 'Colada por la puerta de atrás',
                cantidad: 1,
                costoUnitario: 100,
              ),
            ),
        throwsA(isA<Exception>()),
      );
      expect(
        () => db.customStatement(
          'DELETE FROM compra_detalles WHERE compra_id = ${r.compraId}',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('una remisión sin líneas no se puede dar por terminada', () async {
      final abierta =
          await compras.crear(proveedorId: proveedorId) as CompraAbierta;

      final resultado = await compras.terminar(abierta.compraId);

      expect(resultado, isA<Fallo>());
      expect((resultado as Fallo).mensaje, contains('ni una línea'));
    });

    test('el borrador vacío se descarta y no deja rastro', () async {
      // Es lo que hace la ficha al salir sin haber anotado nada: si no, el
      // listado se llenaría de cuadros abiertos por error.
      final abierta =
          await compras.crear(proveedorId: proveedorId) as CompraAbierta;

      expect(await compras.descartarVacia(abierta.compraId), isA<Exito>());

      final filas = await db
          .customSelect('SELECT COUNT(*) AS n FROM compras')
          .getSingle();
      expect(filas.read<int>('n'), 0);
    });

    test('el borrador con mercancía dentro no se descarta', () async {
      final r = await _compra(terminada: false) as CompraAbierta;

      final resultado = await compras.descartarVacia(r.compraId);

      expect(resultado, isA<Fallo>());
      expect((resultado as Fallo).mensaje, contains('anularla'));
      // Y la base lo impide igual, aunque se intente a mano.
      expect(
        () => db.customStatement('DELETE FROM compras WHERE id = ${r.compraId}'),
        throwsA(isA<Exception>()),
      );
    });

    test('un borrador con líneas sí se anula, y devuelve la mercancía',
        () async {
      final r = await _compra(cantidad: 12, terminada: false) as CompraAbierta;

      expect(await compras.anular(r.compraId), isA<Exito>());

      expect(await _stock(), 10);
      expect((await compras.obtenerDetalle(r.compraId)).resumen.estado,
          EstadoCompra.anulada);
      expect(await inventario.descuadres(), isEmpty);
    });

    test('terminar dos veces se rechaza', () async {
      final r = await _compra() as CompraAbierta;

      final segunda = await compras.terminar(r.compraId);

      expect(segunda, isA<Fallo>());
      expect((segunda as Fallo).mensaje, contains('ya está registrada'));
    });
  });

  group('el costo real deja de ser un número tecleado una vez', () {
    test('registrar la compra deja el costo en el producto', () async {
      expect(await _precioCompra(), 18000, reason: 'el de la siembra');

      await _compra(costo: 6500);

      expect(await _precioCompra(), 6500);
    });

    test('la última compra dice a cómo y a quién se le compró', () async {
      await _compra(cantidad: 4, costo: 6000, factura: 'FV-1');
      await _compra(cantidad: 2, costo: 7200, factura: 'FV-2');

      final ultima =
          await compras.observarUltimaCompra(taller.productoId).first;

      expect(ultima, isNotNull);
      expect(ultima!.costoUnitario, 7200);
      expect(ultima.cantidad, 2);
      expect(ultima.proveedorNombre, 'Repuestos JR');
    });

    test('una compra anulada no cuenta como la última', () async {
      final vieja = await _compra(costo: 6000, factura: 'FV-1');
      final nueva = await _compra(costo: 7200, factura: 'FV-2');
      expect(vieja, isA<CompraAbierta>());

      await compras.anular((nueva as CompraAbierta).compraId);

      final ultima =
          await compras.observarUltimaCompra(taller.productoId).first;
      expect(ultima!.costoUnitario, 6000);
    });

    test('cuánto se le lleva comprado a un proveedor', () async {
      await _compra(cantidad: 10, costo: 5000, factura: 'FV-1'); // 50.000
      await _compra(cantidad: 2, costo: 7000, factura: 'FV-2'); // 14.000

      final resumen =
          await compras.observarResumenProveedor(proveedorId).first;

      expect(resumen.comprasMes, 2);
      expect(resumen.invertidoMes, 64000);
      expect(resumen.invertidoTotal, 64000);
      expect(resumen.ultimaCompra, isNotNull);
    });
  });

  group('anular saca lo que había entrado', () {
    test('el stock vuelve a donde estaba y la compra queda anulada', () async {
      final r = await _compra(cantidad: 12) as CompraAbierta;
      expect(await _stock(), 22);

      final resultado = await compras.anular(r.compraId);

      expect(resultado, isA<Exito>());
      expect(await _stock(), 10);
      expect((await compras.obtenerDetalle(r.compraId)).resumen.estado,
          EstadoCompra.anulada);
      expect(await inventario.descuadres(), isEmpty);
    });

    test('no se anula lo que ya se vendió', () async {
      // Deshacer la entrada dejaría el inventario en negativo. Ahí el camino
      // es un ajuste, no una anulación.
      final r = await _compra(cantidad: 12) as CompraAbierta;
      await db.customStatement(
        'UPDATE productos SET stock_actual = 3 WHERE id = ${taller.productoId}',
      );

      final resultado = await compras.anular(r.compraId);

      expect(resultado, isA<Fallo>());
      expect((resultado as Fallo).mensaje, contains('ya salió del taller'));
      expect((await compras.obtenerDetalle(r.compraId)).resumen.estado,
          EstadoCompra.registrada,
          reason: 'la compra se quedó como estaba');
    });

    test('anular dos veces no saca la mercancía dos veces', () async {
      final r = await _compra(cantidad: 12) as CompraAbierta;
      await compras.anular(r.compraId);

      final segunda = await compras.anular(r.compraId);

      expect(segunda, isA<Fallo>());
      expect(await _stock(), 10);
    });
  });

  group('lo que la base y el repositorio rechazan', () {
    test('la misma factura del mismo proveedor no entra dos veces', () async {
      await _compra(factura: 'FV-2291');

      final segunda = await _compra(factura: 'FV-2291');

      expect(segunda, isA<CompraRechazada>());
      expect((segunda as CompraRechazada).motivo, MotivoFallo.remisionDuplicada);
      expect(await _stock(), 22, reason: 'la segunda no entró');
    });

    test('la misma factura de otro proveedor sí, porque es otra', () async {
      final otro = await _proveedor(nombre: 'Motopartes del Sur');
      await _compra(factura: 'FV-2291');

      final segunda = await _compra(factura: 'FV-2291', deProveedor: otro);

      expect(segunda, isA<CompraAbierta>());
    });

    test('varias compras sin número de factura conviven', () async {
      // El UNIQUE compuesto admite tantos NULL como haga falta: lo que llega
      // sin papel es lo más común del mostrador.
      expect(await _compra(factura: null), isA<CompraAbierta>());
      expect(await _compra(factura: null), isA<CompraAbierta>());
    });

    test('una remisión repetida no quema consecutivo', () async {
      await _compra(factura: 'FV-2291');

      await _compra(factura: 'FV-2291');

      final filas = await db
          .customSelect('SELECT COUNT(*) AS n FROM compras')
          .getSingle();
      expect(filas.read<int>('n'), 1, reason: 'la segunda no llegó a existir');
    });

    test('sin permiso no se registra nada', () async {
      final mirona = await sesionDePrueba(
        db,
        permisos: {Permiso.comprasVer},
        usuario: 'auxiliar',
      );
      final soloLectura = RepositorioComprasImpl(db, mirona);

      final abierta = await soloLectura.crear(proveedorId: proveedorId);
      expect(abierta, isA<CompraRechazada>());

      // Y tampoco por la puerta de atrás: con la compra abierta por otra
      // cuenta, anotarle una línea sigue pidiendo el permiso.
      final mia = await _compra() as CompraAbierta;
      final linea = await soloLectura.agregarLinea(
        compraId: mia.compraId,
        productoId: taller.productoId,
        cantidad: 1,
        costoUnitario: 100,
      );

      expect(linea, isA<Fallo>());
      expect(await _stock(), 22, reason: 'solo entró la línea legítima');
    });

    test('una compra no se borra: se anula', () async {
      final r = await _compra() as CompraAbierta;

      expect(
        () => db.customStatement('DELETE FROM compras WHERE id = ${r.compraId}'),
        throwsA(isA<Exception>()),
      );
    });

    test('una compra anulada ya no se toca', () async {
      final r = await _compra() as CompraAbierta;
      await compras.anular(r.compraId);

      expect(
        () => db.customStatement(
          "UPDATE compras SET estado = 'REGISTRADA' WHERE id = ${r.compraId}",
        ),
        throwsA(isA<Exception>()),
      );
      expect(
        () => db.into(db.tablaCompraDetalle).insert(
              TablaCompraDetalleCompanion.insert(
                compraId: r.compraId,
                productoId: taller.productoId,
                descripcion: 'Colada después de anular',
                cantidad: 1,
                costoUnitario: 100,
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('un estado inventado se rechaza', () async {
      final r = await _compra() as CompraAbierta;

      expect(
        () => db.customStatement(
          "UPDATE compras SET estado = 'EN_CAMINO' WHERE id = ${r.compraId}",
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('un movimiento no puede venir de dos documentos a la vez', () async {
      // El CHECK polimórfico ahora cuenta cinco columnas: si al agregar
      // `compra_id` se hubiera quedado en cuatro, esto pasaría. La factura se
      // inserta de verdad para que lo que rechace sea el CHECK y no la FK.
      final r = await _compra() as CompraAbierta;
      final ventaId = await db.into(db.tablaVentas).insert(
            TablaVentasCompanion.insert(
              numeroFactura: 'FAC-9999',
              usuarioId: sesion.usuarioId,
            ),
          );

      expect(
        () => db.customStatement(
          'UPDATE movimientos_inventario SET venta_id = $ventaId '
          'WHERE compra_id = ${r.compraId}',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('el listado se recorta en SQL', () {
    test('el filtro se aplica igual a la página y al total', () async {
      final otro = await _proveedor(nombre: 'Motopartes del Sur');
      await _compra(factura: 'FV-1');
      await _compra(factura: 'FV-2');
      await _compra(factura: 'FV-3', deProveedor: otro);

      final pagina = await compras
          .observarPagina(
            filtro: FiltroCompras(proveedorId: proveedorId),
            pagina: 0,
            tamano: 1,
          )
          .first;

      expect(pagina.items, hasLength(1), reason: 'el LIMIT recorta');
      expect(pagina.total, 2, reason: 'el total cuenta las dos del proveedor');
      expect(pagina.items.single.lineas, 1);
    });

    test('la suma es la del periodo filtrado, no la de la página', () async {
      // El pie decía «En esta página: $X». Con tres remisiones y una página de
      // una, sumar lo visible habría reportado un tercio del gasto del mes.
      await _compra(cantidad: 10, costo: 5000, factura: 'FV-1');
      await _compra(cantidad: 10, costo: 5000, factura: 'FV-2');
      await _compra(cantidad: 10, costo: 5000, factura: 'FV-3');

      final pagina = await compras
          .observarPagina(
            filtro: const FiltroCompras(),
            pagina: 0,
            tamano: 1,
          )
          .first;

      expect(pagina.items, hasLength(1));
      expect(pagina.suma, 150000);
    });

    test('la suma deja fuera la anulada y el borrador', () async {
      // La anulada devolvió su mercancía; el borrador todavía se está
      // tecleando y meterlo en el gasto lo haría subir y bajar mientras
      // alguien cuenta una caja.
      await _compra(cantidad: 10, costo: 5000, factura: 'FV-1');
      final anulada = await _compra(cantidad: 10, costo: 5000, factura: 'FV-2')
          as CompraAbierta;
      await compras.anular(anulada.compraId);
      await _compra(
        cantidad: 10,
        costo: 5000,
        factura: 'FV-3',
        terminada: false,
      );

      final pagina = await compras
          .observarPagina(
            filtro: const FiltroCompras(),
            pagina: 0,
            tamano: 10,
          )
          .first;

      expect(pagina.total, 3, reason: 'las tres siguen en el listado');
      expect(pagina.suma, 50000);
    });

    test('la búsqueda mira el número del taller y el del proveedor', () async {
      await _compra(factura: 'FV-2291');

      final porFactura = await compras
          .observarPagina(
            filtro: const FiltroCompras(busqueda: '2291'),
            pagina: 0,
            tamano: 10,
          )
          .first;
      final porProveedor = await compras
          .observarPagina(
            filtro: const FiltroCompras(busqueda: 'Repuestos'),
            pagina: 0,
            tamano: 10,
          )
          .first;

      expect(porFactura.total, 1);
      expect(porProveedor.total, 1);
    });

    test('los contadores del mes salen de un COUNT/SUM', () async {
      await _compra(cantidad: 10, costo: 5000, factura: 'FV-1');
      final anulada = await _compra(cantidad: 2, costo: 7000, factura: 'FV-2')
          as CompraAbierta;
      await compras.anular(anulada.compraId);

      final resumen = await compras.observarResumen().first;

      expect(resumen.comprasMes, 1, reason: 'la anulada no cuenta');
      expect(resumen.invertidoMes, 50000);
      expect(resumen.proveedoresMes, 1);
      expect(resumen.anuladas, 1);
    });

    test('sin compras los cuatro números son cero, no null', () async {
      final resumen = await compras.observarResumen().first;

      expect(resumen.comprasMes, 0);
      expect(resumen.invertidoMes, 0);
      expect(resumen.proveedoresMes, 0);
      expect(resumen.anuladas, 0);
    });

    test('sin permiso de ver, el listado ni se abre', () async {
      final sinPermiso = await sesionDePrueba(
        db,
        permisos: const {},
        usuario: 'cajero',
      );

      expect(
        () => RepositorioComprasImpl(db, sinPermiso).observarPagina(
          filtro: const FiltroCompras(),
          pagina: 0,
          tamano: 10,
        ),
        throwsA(isA<PermisoDenegado>()),
      );
    });
  });

  group('la compra deja rastro de quién la hizo', () {
    test('la cabecera firma y la bitácora anota', () async {
      final r = await _compra() as CompraAbierta;

      final compra = await db.customSelect(
        'SELECT usuario_id FROM compras WHERE id = ?',
        variables: [Variable.withInt(r.compraId)],
      ).getSingle();
      expect(compra.read<int>('usuario_id'), sesion.usuarioId);

      final renglon = await db.customSelect(
        "SELECT accion, descripcion FROM bitacora WHERE entidad = 'COMPRA' "
        'ORDER BY id LIMIT 1',
      ).getSingle();
      expect(renglon.read<String>('accion'), 'CREO');
      expect(renglon.read<String>('descripcion'), contains(r.numero));
    });

    test('anular también deja su renglón', () async {
      final r = await _compra() as CompraAbierta;
      await compras.anular(r.compraId);

      final renglones = await db.customSelect(
        "SELECT accion FROM bitacora WHERE entidad = 'COMPRA' ORDER BY id",
      ).get();

      // Abrirla, darla por terminada y anularla: los tres gestos quedan.
      expect(renglones.map((f) => f.read<String>('accion')),
          ['CREO', 'MODIFICO', 'ANULO']);
    });
  });
}
