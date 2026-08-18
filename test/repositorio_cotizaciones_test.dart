// Paginación, filtro por estado y resumen del repositorio de cotizaciones.
//
// Corre contra una base SQLite en memoria. Lo que más importa comprobar aquí es
// que el **estado** (vigente / por vencer / vencida) se resuelve en SQL
// comparando `vigencia_hasta` con la fecha de hoy: antes se calculaba en Dart
// recorriendo la lista entera, así que ni el filtro ni el conteo podían
// apoyarse en él.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/clientes/modelo/cliente.dart';
import 'package:inventario_k1/backend/features/clientes/repositorio/repositorio_cliente_impl.dart';
import 'package:inventario_k1/backend/features/cotizaciones/enum/enum_cotizacion.dart';
import 'package:inventario_k1/backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import 'package:inventario_k1/backend/features/cotizaciones/repositorio/repositorio_cotizaciones.dart';
import 'package:inventario_k1/backend/features/cotizaciones/repositorio/repositorio_cotizaciones_impl.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/features/productos/repositorio/repositorio_producto_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/core/iva_app.dart';
import 'soporte/base_en_memoria.dart';

late AppDb db;
late RepositorioCotizacionesImpl repo;
late RepositorioClientesImpl clientes;
late RepositorioProductosImpl productos;

/// Medianoche del día que está a [dias] de hoy.
///
/// A medianoche y no «ahora + N días» porque `vigencia_hasta` es una fecha sin
/// hora: si llevara la hora actual, una cotización que vence hoy contaría como
/// vigente hasta la tarde.
DateTime _enDias(int dias) {
  final f = DateTime.now().add(Duration(days: dias));
  return DateTime(f.year, f.month, f.day);
}

/// Producto del catálogo al que apuntan las líneas de prueba.
///
/// No es decorativo: `cotizacion_items` exige que una línea `PRODUCTO` traiga
/// un `producto_id` real, así que una cotización de prueba necesita catálogo.
late int productoId;

/// Servicio del catálogo, por el mismo motivo: una línea `SERVICIO` exige un
/// `servicio_id` real.
late int servicioId;

Future<int> _cotizacion({
  required int diasDeVigencia,
  int? clienteId,
  int precio = 10000,
  double cantidad = 1,
}) =>
    repo.crear(
      clienteId: clienteId,
      vigenciaHasta: _enDias(diasDeVigencia),
      items: [
        ItemDraft(
          tipo: TipoItemCotizacion.producto,
          referenciaId: productoId,
          descripcion: 'Repuesto',
          cantidad: cantidad,
          precioUnitario: precio,
        ),
      ],
    );

Future<List<String>> _numeros(FiltroCotizaciones filtro) async {
  final pagina =
      await repo.observarPagina(filtro: filtro, pagina: 0, tamano: 50).first;
  return pagina.items.map((c) => c.numero).toList();
}

void main() {
  setUp(() async {
    db = baseEnMemoria();
    repo = RepositorioCotizacionesImpl(db);
    clientes = RepositorioClientesImpl(db);
    productos = RepositorioProductosImpl(db);
    productoId = (await productos.crear(
      const Producto(
        sku: 'REP-1',
        nombre: 'Repuesto',
        precioCompra: 5000,
        precioVenta: 10000,
        stockActual: 0,
        stockMinimo: 0,
        aplicaIva: false,
        activo: true,
      ),
    ))
        .id!;
    servicioId = await db
        .into(db.tablaServicio)
        .insert(TablaServicioCompanion.insert(nombre: 'Cambio de aceite'));
  });

  tearDown(() async => db.close());

  group('paginación', () {
    test('la página trae solo su tramo pero informa el total real', () async {
      for (var i = 0; i < 7; i++) {
        await _cotizacion(diasDeVigencia: 30);
      }

      final primera = await repo
          .observarPagina(
            filtro: const FiltroCotizaciones(),
            pagina: 0,
            tamano: 3,
          )
          .first;

      expect(primera.items, hasLength(3));
      expect(primera.total, 7, reason: 'el LIMIT no debe afectar al COUNT');

      final ultima = await repo
          .observarPagina(
            filtro: const FiltroCotizaciones(),
            pagina: 2,
            tamano: 3,
          )
          .first;

      expect(ultima.items, hasLength(1));
      expect(ultima.total, 7);
    });

    test('recorrer las páginas no repite ni se salta cotizaciones', () async {
      // Todas se crean en el mismo instante, así que `creado_en` empata y el
      // orden lo decide el desempate por id.
      for (var i = 0; i < 6; i++) {
        await _cotizacion(diasDeVigencia: 30);
      }

      final vistas = <int>[];
      for (var p = 0; p < 3; p++) {
        final pagina = await repo
            .observarPagina(
              filtro: const FiltroCotizaciones(),
              pagina: p,
              tamano: 2,
            )
            .first;
        vistas.addAll(pagina.items.map((c) => c.id));
      }

      expect(vistas, hasLength(6));
      expect(vistas.toSet(), hasLength(6));
    });
  });

  group('filtros', () {
    test('el estado se resuelve en SQL contra la fecha de hoy', () async {
      await _cotizacion(diasDeVigencia: 30); // vigente
      await _cotizacion(diasDeVigencia: 2); //  por vencer
      await _cotizacion(diasDeVigencia: -5); // vencida

      final vigentes =
          await _numeros(const FiltroCotizaciones(estado: EstadoCotizacion.vigente));
      final porVencer = await _numeros(
        const FiltroCotizaciones(estado: EstadoCotizacion.porVencer),
      );
      final vencidas =
          await _numeros(const FiltroCotizaciones(estado: EstadoCotizacion.vencida));

      expect(vigentes, hasLength(1));
      expect(porVencer, hasLength(1));
      expect(vencidas, hasLength(1));

      // Y coincide con lo que calcula el modelo en Dart, que es lo que pinta
      // el badge: si las dos reglas se separaran, la fila diría una cosa y el
      // chip que la filtró, otra.
      final pagina = await repo
          .observarPagina(
            filtro: const FiltroCotizaciones(estado: EstadoCotizacion.vencida),
            pagina: 0,
            tamano: 10,
          )
          .first;
      expect(pagina.items.single.estado, EstadoCotizacion.vencida);
    });

    test('la búsqueda encuentra por número y por nombre del cliente', () async {
      final carlos = await clientes.crear(
        const Cliente(id: 0, nombres: 'Carlos', apellidos: 'Ramírez', activo: true),
      );
      final diana = await clientes.crear(
        const Cliente(id: 0, nombres: 'Diana', apellidos: 'Cardona', activo: true),
      );
      await _cotizacion(diasDeVigencia: 30, clienteId: carlos);
      await _cotizacion(diasDeVigencia: 30, clienteId: diana);

      final porCliente =
          await _numeros(const FiltroCotizaciones(busqueda: 'cardona'));
      expect(porCliente, hasLength(1));

      // El número lo genera el repositorio; se busca un tramo del que salga.
      final todas = await _numeros(const FiltroCotizaciones());
      final unNumero = todas.first;
      final porNumero =
          await _numeros(FiltroCotizaciones(busqueda: unNumero.toLowerCase()));
      expect(porNumero, contains(unNumero));
    });

    test('el total respeta el filtro, no solo la página', () async {
      for (var i = 0; i < 5; i++) {
        await _cotizacion(diasDeVigencia: 30);
      }
      await _cotizacion(diasDeVigencia: -1);

      final pagina = await repo
          .observarPagina(
            filtro: const FiltroCotizaciones(estado: EstadoCotizacion.vigente),
            pagina: 0,
            tamano: 2,
          )
          .first;

      expect(pagina.items, hasLength(2));
      expect(pagina.total, 5, reason: 'cuenta las vigentes, no las seis');
    });
  });

  group('resumen', () {
    test('cuenta cada estado y suma solo el monto que sigue en juego',
        () async {
      await _cotizacion(diasDeVigencia: 30, precio: 100000);
      await _cotizacion(diasDeVigencia: 2, precio: 50000);
      await _cotizacion(diasDeVigencia: -5, precio: 999999);

      final resumen = await repo.observarResumen().first;

      expect(resumen.total, 3);
      expect(resumen.vigentes, 1);
      expect(resumen.porVencer, 1);
      expect(resumen.vencidas, 1);
      expect(
        resumen.montoVigente,
        150000 + ivaDe(100000) + ivaDe(50000),
        reason: 'la vencida no suma',
      );
    });
  });

  group('IVA', () {
    test('la cotización guarda el IVA de la tasa global', () async {
      final id = await _cotizacion(diasDeVigencia: 30, precio: 100000);
      final detalle = await repo.obtenerDetalle(id);

      expect(detalle.resumen.subtotal, 100000);
      expect(detalle.resumen.iva, ivaDe(100000));
      expect(detalle.resumen.total, 100000 + ivaDe(100000));
    });
  });

  group('conteo de ítems', () {
    // La columna "ÍTEMS" del listado. Sale de un COUNT correlacionado: si se
    // resolviera cargando el detalle de cada fila, pintar una página de doce
    // costaría doce consultas más.
    test('cada fila informa cuántas líneas tiene', () async {
      await repo.crear(
        vigenciaHasta: _enDias(30),
        items: [
          ItemDraft(
            tipo: TipoItemCotizacion.producto,
            referenciaId: productoId,
            descripcion: 'Aceite',
            cantidad: 2,
            precioUnitario: 32000,
          ),
          ItemDraft(
            tipo: TipoItemCotizacion.servicio,
            referenciaId: servicioId,
            descripcion: 'Cambio de aceite',
            cantidad: 1,
            precioUnitario: 25000,
          ),
          const ItemDraft(
            tipo: TipoItemCotizacion.libre,
            descripcion: 'Guardabarros',
            cantidad: 1,
            precioUnitario: 80000,
          ),
        ],
      );

      final pagina = await repo
          .observarPagina(
            filtro: const FiltroCotizaciones(),
            pagina: 0,
            tamano: 10,
          )
          .first;

      expect(pagina.items.single.cantidadItems, 3);
    });

    test('el conteo baja al quitarle líneas a la cotización', () async {
      final id = await repo.crear(
        vigenciaHasta: _enDias(30),
        items: [
          const ItemDraft(
            tipo: TipoItemCotizacion.libre,
            descripcion: 'Uno',
            cantidad: 1,
            precioUnitario: 1000,
          ),
          const ItemDraft(
            tipo: TipoItemCotizacion.libre,
            descripcion: 'Dos',
            cantidad: 1,
            precioUnitario: 1000,
          ),
        ],
      );

      await repo.actualizar(
        id: id,
        vigenciaHasta: _enDias(30),
        items: [
          const ItemDraft(
            tipo: TipoItemCotizacion.libre,
            descripcion: 'Uno',
            cantidad: 1,
            precioUnitario: 1000,
          ),
        ],
      );

      final pagina = await repo
          .observarPagina(
            filtro: const FiltroCotizaciones(),
            pagina: 0,
            tamano: 10,
          )
          .first;

      expect(pagina.items.single.cantidadItems, 1);
    });
  });

  group('inventario', () {
    // Una cotización es una propuesta: no compromete stock. Antes `crear` lo
    // descontaba y `eliminar` no lo devolvía, así que borrar una cotización
    // dejaba el inventario hundido sin que nadie lo notara.
    test('cotizar un producto no mueve su stock', () async {
      final producto = await productos.crear(
        const Producto(
          sku: 'SKU-1123',
          nombre: 'Aceite Motul 20W50',
          precioCompra: 20000,
          precioVenta: 32000,
          stockActual: 12,
          stockMinimo: 2,
          aplicaIva: false,
          activo: true,
        ),
      );

      final id = await repo.crear(
        vigenciaHasta: _enDias(30),
        items: [
          ItemDraft(
            tipo: TipoItemCotizacion.producto,
            referenciaId: producto.id,
            descripcion: producto.nombre,
            cantidad: 5,
            precioUnitario: 32000,
          ),
        ],
      );
      expect(
        (await productos.obtenerPorId(producto.id!))!.stockActual,
        12,
        reason: 'crear no descuenta',
      );

      await repo.actualizar(
        id: id,
        vigenciaHasta: _enDias(30),
        items: [
          ItemDraft(
            tipo: TipoItemCotizacion.producto,
            referenciaId: producto.id,
            descripcion: producto.nombre,
            cantidad: 9,
            precioUnitario: 32000,
          ),
        ],
      );
      expect(
        (await productos.obtenerPorId(producto.id!))!.stockActual,
        12,
        reason: 'editar no descuenta ni restaura',
      );

      await repo.eliminar(id);
      expect((await productos.obtenerPorId(producto.id!))!.stockActual, 12);
    });

    test('se puede cotizar un producto sin stock', () async {
      final agotado = await productos.crear(
        const Producto(
          sku: 'SKU-1201',
          nombre: 'Pastilla de freno',
          precioCompra: 30000,
          precioVenta: 45000,
          stockActual: 0,
          stockMinimo: 1,
          aplicaIva: false,
          activo: true,
        ),
      );

      await repo.crear(
        vigenciaHasta: _enDias(30),
        items: [
          ItemDraft(
            tipo: TipoItemCotizacion.producto,
            referenciaId: agotado.id,
            descripcion: agotado.nombre,
            cantidad: 3,
            precioUnitario: 45000,
          ),
        ],
      );

      // Sin negativos: cotizar lo que hay que pedir es normal en un taller.
      expect((await productos.obtenerPorId(agotado.id!))!.stockActual, 0);
    });
  });

  group('tipos de ítem', () {
    test('guarda servicios y líneas libres, no solo productos', () async {
      final id = await repo.crear(
        vigenciaHasta: _enDias(30),
        items: [
          ItemDraft(
            tipo: TipoItemCotizacion.producto,
            referenciaId: productoId,
            descripcion: 'Aceite 20W50',
            cantidad: 2,
            precioUnitario: 32000,
          ),
          ItemDraft(
            tipo: TipoItemCotizacion.servicio,
            referenciaId: servicioId,
            descripcion: 'Cambio de aceite',
            cantidad: 1,
            precioUnitario: 25000,
          ),
          const ItemDraft(
            tipo: TipoItemCotizacion.libre,
            descripcion: 'Repuesto conseguido afuera',
            cantidad: 1,
            precioUnitario: 80000,
          ),
        ],
      );

      final detalle = await repo.obtenerDetalle(id);
      final tipos = detalle.items.map((i) => i.tipoItem).toList();

      expect(tipos, [
        TipoItemCotizacion.producto,
        TipoItemCotizacion.servicio,
        TipoItemCotizacion.libre,
      ]);
      // La línea libre no referencia ningún catálogo.
      expect(detalle.items.last.referenciaId, isNull);
      expect(detalle.resumen.subtotal, 64000 + 25000 + 80000);
    });
  });

  group('la referencia al catálogo la verifica la base', () {
    // Antes era un `referencia_id` suelto con un `tipo_item` al lado: nada
    // impedía que una línea de producto apuntara al id de un servicio, ni que
    // apuntara a nada. Ahora son dos columnas con FK y un CHECK.
    test('cada tipo guarda su referencia en la columna que le toca', () async {
      final id = await repo.crear(
        vigenciaHasta: _enDias(30),
        items: [
          ItemDraft(
            tipo: TipoItemCotizacion.producto,
            referenciaId: productoId,
            descripcion: 'Aceite',
            cantidad: 1,
            precioUnitario: 32000,
          ),
          ItemDraft(
            tipo: TipoItemCotizacion.servicio,
            referenciaId: servicioId,
            descripcion: 'Cambio de aceite',
            cantidad: 1,
            precioUnitario: 25000,
          ),
        ],
      );

      final filas = await db
          .customSelect('SELECT tipo_item, producto_id, servicio_id '
              'FROM cotizacion_items WHERE cotizacion_id = $id '
              'ORDER BY id')
          .get();

      expect(filas.first.read<int?>('producto_id'), productoId);
      expect(filas.first.read<int?>('servicio_id'), isNull);
      expect(filas.last.read<int?>('servicio_id'), servicioId);
      expect(filas.last.read<int?>('producto_id'), isNull);
    });

    test('una línea de producto sin producto no se admite', () async {
      expect(
        () => repo.crear(
          vigenciaHasta: _enDias(30),
          items: const [
            ItemDraft(
              tipo: TipoItemCotizacion.producto,
              descripcion: 'Fantasma',
              cantidad: 1,
              precioUnitario: 1000,
            ),
          ],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('una línea de producto no puede apuntar a un producto inexistente',
        () async {
      expect(
        () => repo.crear(
          vigenciaHasta: _enDias(30),
          items: const [
            ItemDraft(
              tipo: TipoItemCotizacion.producto,
              referenciaId: 9999,
              descripcion: 'Fantasma',
              cantidad: 1,
              precioUnitario: 1000,
            ),
          ],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('no se borra un producto que está en una cotización', () async {
      await _cotizacion(diasDeVigencia: 30);

      expect(
        () => db.customStatement(
            'DELETE FROM productos WHERE id = $productoId'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('lo que se deduce no se guarda', () {
    test('el total sale de subtotal + iva, no de una columna', () async {
      final id = await _cotizacion(diasDeVigencia: 30, precio: 50000);

      final detalle = await repo.obtenerDetalle(id);
      expect(detalle.resumen.total,
          detalle.resumen.subtotal + detalle.resumen.iva);

      final columnas = await db
          .customSelect("SELECT name FROM pragma_table_info('cotizaciones')")
          .get();
      final nombres = columnas.map((c) => c.read<String>('name')).toList();
      expect(nombres, isNot(contains('total')),
          reason: 'era subtotal + iva, dos columnas de su misma fila');
    });

    test('el estado tampoco: depende de la fecha de hoy', () async {
      final columnas = await db
          .customSelect("SELECT name FROM pragma_table_info('cotizaciones')")
          .get();
      final nombres = columnas.map((c) => c.read<String>('name')).toList();
      expect(nombres, isNot(contains('estado')));
    });
  });

  group('los CHECK del esquema', () {
    test('una línea con cantidad cero se rechaza', () async {
      expect(
        () => repo.crear(
          vigenciaHasta: _enDias(30),
          items: [
            ItemDraft(
              tipo: TipoItemCotizacion.producto,
              referenciaId: productoId,
              descripcion: 'Aceite',
              cantidad: 0,
              precioUnitario: 1000,
            ),
          ],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('el número de cotización no se repite', () async {
      final id = await _cotizacion(diasDeVigencia: 30);
      final numero = (await repo.obtenerDetalle(id)).resumen.numero;

      expect(
        () => db.into(db.tablaCotizacion).insert(
              TablaCotizacionCompanion.insert(
                numero: numero,
                vigenciaHasta: DateTime(2026, 12, 31),
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
