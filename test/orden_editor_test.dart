// El editor de órdenes contra una base de verdad, en memoria.
//
// A diferencia del editor de cotizaciones —que se prueba con un repositorio de
// mentira— aquí el repositorio **es** lo que hay que probar de la mano del
// notifier: el guardado es incremental (una llamada por línea) y cada
// escritura se sigue de una relectura. Con un doble solo se estaría afirmando
// lo que el propio doble finge.
//
// Se puede hacer en un `test()` normal porque el notifier solo usa `Future`s:
// `obtenerDetalle`, `agregarTarea`, `eliminarRepuesto`… Los `Stream` de Drift
// están en los providers del catálogo, que estos tests no tocan (ver
// `test/soporte/base_en_memoria.dart` y la nota de §10).
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/ordenes/enum/enum_ordenes.dart';
import 'package:inventario_k1/backend/features/ordenes/repositorio/repositorio_ordenes_impl.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/features/servicios/modelo/servicio.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/database/app_db_provider.dart';
import 'package:inventario_k1/core/resultado.dart';
import 'package:inventario_k1/frontend/features/ordenes/orden_detalle/modelo/linea_orden_editor.dart';
import 'package:inventario_k1/frontend/features/ordenes/orden_detalle/modelo/orden_editor_state.dart';
import 'package:inventario_k1/frontend/features/ordenes/orden_detalle/provider/orden_editor_provider.dart';
import 'package:inventario_k1/frontend/features/ordenes/orden_detalle/provider/validacion_orden.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/datos_taller.dart';
import 'soporte/sesion_de_prueba.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';
import 'package:inventario_k1/frontend/features/autenticacion/provider/auth_providers.dart';

late AppDb db;

/// Quien firma lo que escriben estos tests. Ver `sesionDePrueba`.
late SesionActual sesion;
late RepositorioOrdenesImpl repo;
late DatosTaller taller;
late ProviderContainer container;
late int ordenId;

OrdenEditorNotifier get _notifier =>
    container.read(ordenEditorProvider(ordenId).notifier);

OrdenEditorState get _estado =>
    container.read(ordenEditorProvider(ordenId)).value!;

Future<double> _stock() async {
  final fila = await db
      .customSelect(
        'SELECT stock_actual AS s FROM productos WHERE id = ?',
        variables: [Variable.withInt(taller.productoId)],
      )
      .getSingle();
  return fila.read<double>('s');
}

/// Monta el editor sobre la orden recién creada y espera a que cargue.
Future<void> _montar() async {
  container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      // Los repositorios que arma Riverpod reciben la sesión por el
      // constructor. Sin este override serían anónimos y `usuario_id`, que es
      // `NOT NULL`, no tendría con qué llenarse.
      sesionActualProvider.overrideWithValue(sesion),
    ],
  );
  addTearDown(container.dispose);

  // Sin oyente, un `AsyncNotifier` de Riverpod 3 no llega a construirse.
  container.listen(ordenEditorProvider(ordenId), (_, _) {});
  await container.read(ordenEditorProvider(ordenId).future);
}

Future<Resultado> _cerrarOrden([EstadoOrden a = EstadoOrden.lista]) =>
    _notifier.cambiarEstado(a);

void main() {
  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
    repo = RepositorioOrdenesImpl(db, sesion);
    taller = await sembrarTaller(db);
    final orden = await repo.agregar(
      motoId: taller.motoId,
      clienteId: taller.clienteId,
      kilometrajeEntrada: 15000,
      diagnostico: 'No enciende',
    );
    ordenId = orden.id;
    await _montar();
  });

  tearDown(() => db.close());

  group('el editor carga la orden que ya existe', () {
    test('trae número, moto, cliente y cabecera', () {
      expect(_estado.numero, 'ORD-0001');
      expect(_estado.clienteNombre, contains('Carlos'));
      expect(_estado.motoDescripcion, contains('Pulsar'));
      expect(_estado.motoPlaca, 'KMN12C');
      expect(_estado.kilometrajeEntrada, 15000);
      expect(_estado.diagnostico, 'No enciende');
      expect(_estado.estado, EstadoOrden.abierta);
      expect(_estado.lineas, isEmpty);
    });

    test('empieza en "guardada": la orden ya está en la base', () {
      // No existe el "sin cambios" de cotizaciones porque no existe el caso
      // "todavía no se ha creado nada".
      expect(_estado.guardado, EstadoGuardadoOrden.guardado);
    });
  });

  group('las líneas se escriben una a una, no reemplazando el documento', () {
    test('agregar un repuesto lo deja en la base con su id', () async {
      await _notifier.agregarProducto(_producto());

      final linea = _estado.lineas.single;
      expect(linea.tipo, TipoLineaOrden.repuesto);
      expect(linea.descripcion, 'Pastilla de freno');
      expect(linea.cantidad, 1);
      // El id sale de la relectura: sin él no habría a qué apuntarle un
      // `eliminarRepuesto`.
      expect(linea.id, greaterThan(0));

      final detalle = await repo.obtenerDetalle(ordenId);
      expect(detalle.repuestos.single.id, linea.id);
    });

    test('el mismo repuesto dos veces suma cantidad, no abre otra línea',
        () async {
      await _notifier.agregarProducto(_producto());
      await _notifier.agregarProducto(_producto());
      await _notifier.guardarAhora();

      expect(_estado.lineas, hasLength(1));
      expect(_estado.lineas.single.cantidad, 2);

      final detalle = await repo.obtenerDetalle(ordenId);
      expect(detalle.repuestos, hasLength(1), reason: 'una sola fila');
      expect(detalle.repuestos.single.cantidad, 2);
    });

    test('agregar un servicio guarda su técnico y su precio', () async {
      await _notifier.agregarServicio(
        _servicio(),
        tecnicoId: taller.tecnicoId,
        precio: 50000,
      );

      final linea = _estado.lineas.single;
      expect(linea.tipo, TipoLineaOrden.servicio);
      expect(linea.tecnicoId, taller.tecnicoId);
      expect(linea.tecnicoNombre, 'Ana Torres');
      expect(linea.precioUnitario, 50000);
    });

    test('agregar un cargo suelto no toca el inventario', () async {
      final antes = await _stock();
      await _notifier.agregarCargo(descripcion: 'Domicilio', precio: 8000);

      expect(_estado.lineas.single.tipo, TipoLineaOrden.cargo);
      expect(await _stock(), antes, reason: 'un cargo no sale del estante');
    });

    test('eliminar una línea la borra de su propia tabla', () async {
      await _notifier.agregarProducto(_producto());
      await _notifier.agregarCargo(descripcion: 'Domicilio', precio: 8000);

      final repuesto = _estado.lineas
          .firstWhere((l) => l.tipo == TipoLineaOrden.repuesto);
      await _notifier.eliminarLinea(repuesto);

      expect(_estado.lineas, hasLength(1));
      expect(_estado.lineas.single.tipo, TipoLineaOrden.cargo,
          reason: 'el cargo sigue: borrar el repuesto no lo tocó');
    });

    test('marcar una tarea hecha conserva su id', () async {
      await _notifier.agregarServicio(
        _servicio(),
        tecnicoId: taller.tecnicoId,
        precio: 50000,
      );
      final antes = _estado.lineas.single.id;

      await _notifier.marcarCompletada(_estado.lineas.single, hecha: true);

      // Es lo que un `DELETE + INSERT` habría roto: la tarea sería otra fila y
      // `completado` se habría perdido en el camino.
      expect(_estado.lineas.single.id, antes);
      expect(_estado.lineas.single.completado, isTrue);
    });
  });

  group('teclear espera el retardo; agregar y quitar no', () {
    test('cambiar el precio responde en pantalla antes de escribir', () async {
      await _notifier.agregarCargo(descripcion: 'Domicilio', precio: 8000);
      final cargo = _estado.lineas.single;

      _notifier.cambiarPrecio(cargo, 12000);

      // La pantalla ya lo dice…
      expect(_estado.lineas.single.precioUnitario, 12000);
      expect(_estado.guardado, EstadoGuardadoOrden.pendiente);
      // …pero la base todavía no.
      final detalle = await repo.obtenerDetalle(ordenId);
      expect(detalle.cargos.single.precio, 8000);
    });

    test('guardarAhora escribe lo que estaba esperando', () async {
      await _notifier.agregarCargo(descripcion: 'Domicilio', precio: 8000);
      _notifier.cambiarPrecio(_estado.lineas.single, 12000);

      await _notifier.guardarAhora();

      expect(_estado.guardado, EstadoGuardadoOrden.guardado);
      final detalle = await repo.obtenerDetalle(ordenId);
      expect(detalle.cargos.single.precio, 12000);
    });

    test('dos campos distintos se escriben los dos, no se pisan', () async {
      await _notifier.agregarCargo(descripcion: 'Domicilio', precio: 8000);
      _notifier.cambiarPrecio(_estado.lineas.single, 12000);
      _notifier.cambiarDiagnostico('Cambió el ruido');

      await _notifier.guardarAhora();

      final detalle = await repo.obtenerDetalle(ordenId);
      expect(detalle.cargos.single.precio, 12000);
      expect(detalle.diagnosticoCliente, 'Cambió el ruido');
    });

    test('una relectura no pisa lo que se está tecleando', () async {
      await _notifier.agregarCargo(descripcion: 'Domicilio', precio: 8000);
      _notifier.cambiarDiagnostico('A medio escribir');

      // Agregar otra línea escribe y relee. Si la relectura no respetara lo
      // pendiente, el diagnóstico volvería al valor de la base.
      await _notifier.agregarCargo(descripcion: 'Lavado', precio: 5000);

      expect(_estado.diagnostico, 'A medio escribir');
    });
  });

  group('el inventario se mueve al anotar, y el editor lo refleja', () {
    test('agregar un repuesto descuenta en el acto', () async {
      final antes = await _stock();

      await _notifier.agregarProducto(_producto());

      expect(await _stock(), antes - 1);
      expect(_estado.inventarioDevuelto, isFalse);
    });

    test('pasar a LISTA ya no mueve nada', () async {
      final antes = await _stock();
      await _notifier.agregarProducto(_producto());
      await _notifier.agregarProducto(_producto());
      expect(await _stock(), antes - 2, reason: 'salieron al agregarlas');

      await _cerrarOrden();

      expect(await _stock(), antes - 2);
      expect(_estado.estado, EstadoOrden.lista);
    });

    test('si el stock no alcanza, la línea no entra y el editor lo dice',
        () async {
      // Stock 10. Se sube la línea a 10 y se intenta agregar una más.
      await _notifier.agregarProducto(_producto());
      _notifier.cambiarCantidad(_estado.lineas.single, 10);
      await _notifier.guardarAhora();
      expect(await _stock(), 0);

      final resultado = await _notifier.agregarProducto(_producto());

      expect(resultado, isA<Fallo>());
      expect(await _stock(), 0, reason: 'no se movió nada más');
      expect(_estado.guardado, EstadoGuardadoOrden.bloqueado);
      expect(_estado.lineas.single.cantidad, 10,
          reason: 'la línea se queda como estaba');
    });

    test('el fallo dice qué repuesto faltó, no solo que faltó', () async {
      await _notifier.agregarProducto(_producto());

      _notifier.cambiarCantidad(_estado.lineas.single, 99);
      final resultado = await _notifier.guardarAhora();

      expect(
        resultado,
        isA<Fallo>().having(
          (f) => f.mensaje,
          'mensaje',
          contains('Pastilla de freno'),
        ),
      );
      expect(_estado.motivoBloqueo, contains('Pastilla de freno'));
      expect(_estado.guardado, EstadoGuardadoOrden.bloqueado);
    });

    test('una cantidad que la base rechaza vuelve a su valor real', () async {
      // El estado se actualiza de forma optimista antes de escribir. Sin la
      // relectura del fallo, el panel se quedaría mostrando 99 unidades que el
      // taller no tiene, y el total mentiría con ellas.
      await _notifier.agregarProducto(_producto());
      final precio = _estado.lineas.single.precioUnitario;

      _notifier.cambiarCantidad(_estado.lineas.single, 99);
      expect(_estado.lineas.single.cantidad, 99, reason: 'optimista');

      await _notifier.guardarAhora();

      expect(_estado.lineas.single.cantidad, 1);
      expect(_estado.subtotal, precio);
      expect(await _stock(), 9);
    });

    test('quitar una línea devuelve la pieza al estante', () async {
      final antes = await _stock();
      await _notifier.agregarProducto(_producto());
      expect(await _stock(), antes - 1);

      await _notifier.eliminarLinea(_estado.lineas.single);

      expect(await _stock(), antes);
    });

    test('anular devuelve el stock y el aviso cambia de sentido', () async {
      final antes = await _stock();
      await _notifier.agregarProducto(_producto());
      await _cerrarOrden();
      expect(await _stock(), antes - 1);

      await _notifier.anular();

      expect(_estado.estado, EstadoOrden.anulada);
      expect(await _stock(), antes);
      expect(_estado.inventarioDevuelto, isTrue);
    });

    test('LISTA → ENTREGADA no vuelve a descontar', () async {
      final antes = await _stock();
      await _notifier.agregarProducto(_producto());
      await _cerrarOrden();
      await _cerrarOrden(EstadoOrden.entregada);

      expect(await _stock(), antes - 1, reason: 'una sola salida');
    });
  });

  group('una orden cerrada deja de aceptar líneas', () {
    test('ENTREGADA y ANULADA no son editables', () async {
      expect(_estado.editable, isTrue);

      await _cerrarOrden(EstadoOrden.entregada);
      expect(_estado.editable, isFalse);
    });

    test('LISTA sigue siendo editable: la guarda solo cierra en ENTREGADA',
        () async {
      await _cerrarOrden();
      expect(_estado.editable, isTrue);
    });

    test('una orden anulada no se reabre', () async {
      await _notifier.anular();

      final resultado = await _notifier.cambiarEstado(EstadoOrden.abierta);

      expect(resultado, isA<Fallo>());
      expect(_estado.estado, EstadoOrden.anulada);
    });
  });

  group('descuento y totales', () {
    test('el repositorio recorta el descuento y el editor lo relee', () async {
      await _notifier.agregarCargo(descripcion: 'Domicilio', precio: 8000);
      _notifier.cambiarDescuento(50000);
      await _notifier.guardarAhora();

      // El tope es el subtotal, y lo aplica el repositorio: aquí no hay
      // `CHECK` que lo cubra porque el subtotal es la suma de tres tablas.
      expect(_estado.descuento, 8000);
      expect(_estado.total, 0);
    });

    test('quitar una línea recorta el descuento que dejó de caber', () async {
      await _notifier.agregarCargo(descripcion: 'Domicilio', precio: 8000);
      await _notifier.agregarCargo(descripcion: 'Lavado', precio: 5000);
      _notifier.cambiarDescuento(10000);
      await _notifier.guardarAhora();
      expect(_estado.descuento, 10000);

      final lavado =
          _estado.lineas.firstWhere((l) => l.descripcion == 'Lavado');
      await _notifier.eliminarLinea(lavado);

      expect(_estado.descuento, 8000, reason: 'ya no cabían 10.000');
    });

    test('el total suma los tres bloques y resta la rebaja', () async {
      await _notifier.agregarServicio(
        _servicio(),
        tecnicoId: taller.tecnicoId,
        precio: 50000,
      );
      await _notifier.agregarProducto(_producto());
      await _notifier.agregarCargo(descripcion: 'Domicilio', precio: 8000);
      _notifier.cambiarDescuento(8000);
      await _notifier.guardarAhora();

      // 50.000 + 30.000 + 8.000 = 88.000, menos 8.000. Sin IVA sumado encima:
      // ya viene dentro del precio.
      expect(_estado.subtotal, 88000);
      expect(_estado.total, 80000);
    });
  });

  group('agrupación de líneas', () {
    test('los tres bloques salen en el orden del diseño', () async {
      await _notifier.agregarCargo(descripcion: 'Domicilio', precio: 8000);
      await _notifier.agregarProducto(_producto());
      await _notifier.agregarServicio(
        _servicio(),
        tecnicoId: taller.tecnicoId,
        precio: 50000,
      );

      final grupos = OrdenEditorState.agrupar(_estado.lineas);

      expect(
        grupos.map((g) => g.titulo),
        ['Servicios', 'Repuestos', 'Otros cargos'],
        reason: 'el orden es el del mockup, no el de inserción',
      );
      expect(grupos.first.subtotal, 50000);
    });

    test('un grupo vacío no sale', () async {
      await _notifier.agregarCargo(descripcion: 'Domicilio', precio: 8000);

      final grupos = OrdenEditorState.agrupar(_estado.lineas);

      expect(grupos, hasLength(1));
      expect(grupos.single.titulo, 'Otros cargos');
    });

    test('el técnico de la última tarea precarga el selector', () async {
      expect(_estado.ultimoTecnicoId, isNull);

      await _notifier.agregarServicio(
        _servicio(),
        tecnicoId: taller.tecnicoId,
        precio: 50000,
      );

      expect(_estado.ultimoTecnicoId, taller.tecnicoId);
    });
  });

  group('validación', () {
    test('no deja cerrar con una línea sin precio', () async {
      await _notifier.agregarCargo(descripcion: 'Domicilio', precio: 8000);
      _notifier.cambiarPrecio(_estado.lineas.single, 0);
      await _notifier.guardarAhora();

      final resultado = await _cerrarOrden();

      expect(resultado, isA<Fallo>());
      expect(_estado.estado, EstadoOrden.abierta);
    });

    test('el mensaje de la excepción llega sin el "Exception:" delante', () {
      expect(
        mensajeDeExcepcion(Exception('No hay stock de "X".')),
        'No hay stock de "X".',
      );
    });
  });
}

// Helpers de catálogo — los dos modelos que el editor recibe de la izquierda.
//
// Se construyen a mano en vez de leerlos del repositorio de productos porque
// el editor solo usa cuatro campos de cada uno, y los ids son los que sembró
// `sembrarTaller`.

Producto _producto() => Producto(
      id: taller.productoId,
      sku: 'FRE-1',
      nombre: 'Pastilla de freno',
      precioCompra: 18000,
      precioVenta: 30000,
      stockActual: 10,
      stockMinimo: 0,
      aplicaIva: true,
      activo: true,
    );

Servicio _servicio() => Servicio(
      id: taller.servicioId,
      nombre: 'Sincronización',
      activo: true,
    );
