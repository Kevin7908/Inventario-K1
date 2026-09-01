import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/inventario/modelo/movimiento_inventario.dart';
import 'package:inventario_k1/backend/features/inventario/repositorio/repositorio_inventario.dart';
import 'package:inventario_k1/backend/features/inventario/repositorio/repositorio_inventario_impl.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/features/productos/repositorio/repositorio_producto_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/permiso.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/sesion_de_prueba.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';

late AppDb db;

/// Quien firma lo que escriben estos tests. Ver `sesionDePrueba`.
late SesionActual sesion;
late RepositorioInventarioImpl inventario;
late RepositorioProductosImpl productos;

Producto _producto({
  String sku = 'FRE-1',
  String nombre = 'Pastilla',
  double stock = 0,
  int precioVenta = 32000,
}) =>
    Producto(
      sku: sku,
      nombre: nombre,
      precioCompra: 20000,
      precioVenta: precioVenta,
      stockActual: stock,
      stockMinimo: 2,
      aplicaIva: false,
      activo: true,
    );

Future<double> _stockCache(int productoId) async {
  final fila = await db.customSelect(
    'SELECT stock_actual AS s FROM productos WHERE id = ?',
    variables: [Variable.withInt(productoId)],
  ).getSingle();
  return fila.read<double>('s');
}

void main() {
  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
    inventario = RepositorioInventarioImpl(db, sesion);
    productos = RepositorioProductosImpl(db, sesion);
  });

  tearDown(() => db.close());

  group('el alta y el ajuste dejan su renglón', () {
    test('el stock inicial entra como movimiento, no como columna', () async {
      final creado = await productos.crear(_producto(stock: 10));

      final movimientos =
          await inventario.observarPorProducto(creado.id!).first;

      expect(movimientos, hasLength(1));
      expect(movimientos.single.tipo, TipoMovimiento.ajusteInicial);
      expect(movimientos.single.cantidad, 10);
      expect(await _stockCache(creado.id!), 10);
    });

    test('un producto sin stock inicial no genera movimiento', () async {
      final creado = await productos.crear(_producto());

      expect(await inventario.observarPorProducto(creado.id!).first, isEmpty);
    });

    test('el ajuste elige el tipo según el signo', () async {
      final creado = await productos.crear(_producto(stock: 10));

      await productos.ajustarStock(creado.id!, 5);
      await productos.ajustarStock(creado.id!, -3);

      final tipos = (await inventario.observarPorProducto(creado.id!).first)
          .map((m) => m.tipo)
          .toSet();

      expect(tipos, contains(TipoMovimiento.ajustePositivo));
      expect(tipos, contains(TipoMovimiento.ajusteNegativo));
      expect(await _stockCache(creado.id!), 12);
    });

    test('guardar sin tocar el stock no mueve inventario de rebote', () async {
      final creado = await productos.crear(_producto(stock: 10));

      // El formulario manda el modelo completo, con el stock que leyó. Editar
      // solo el nombre no puede dejar ningún renglón nuevo.
      await productos.actualizar(creado.copyWith(nombre: 'Pastilla trasera'));

      expect(await _stockCache(creado.id!), 10);
      expect(await inventario.observarPorProducto(creado.id!).first,
          hasLength(1));
    });

    test('editar el stock en la ficha deja su ajuste y se queda', () async {
      final creado = await productos.crear(_producto(stock: 10));

      // El campo «stock actual» del formulario no escribía nada —el mapper
      // excluye la columna— y el valor volvía al anterior en cuanto el stream
      // reemitía. Ahora la diferencia entra como ajuste.
      await productos.actualizar(creado.copyWith(stockActual: 14));

      final movimientos =
          await inventario.observarPorProducto(creado.id!).first;

      expect(await _stockCache(creado.id!), 14);
      expect(movimientos, hasLength(2));
      expect(movimientos.first.tipo, TipoMovimiento.ajustePositivo);
      expect(movimientos.first.cantidad, 4);
      expect(await inventario.descuadres(), isEmpty);
    });

    test('bajar el stock desde la ficha entra como ajuste negativo', () async {
      final creado = await productos.crear(_producto(stock: 10));

      await productos.actualizar(creado.copyWith(stockActual: 6));

      final movimientos =
          await inventario.observarPorProducto(creado.id!).first;

      expect(await _stockCache(creado.id!), 6);
      expect(movimientos.first.tipo, TipoMovimiento.ajusteNegativo);
      expect(movimientos.first.cantidad, -4);
      expect(await inventario.descuadres(), isEmpty);
    });
  });

  group('el caché cuadra con el libro mayor', () {
    test('stockReconstruido es la suma de los movimientos', () async {
      final creado = await productos.crear(_producto(stock: 10));
      await productos.ajustarStock(creado.id!, 5);
      await productos.ajustarStock(creado.id!, -8);

      expect(await inventario.stockReconstruido(creado.id!), 7);
      expect(await _stockCache(creado.id!), 7);
    });

    test('no hay descuadres después de una tanda de operaciones', () async {
      final a = await productos.crear(_producto(sku: 'A-1', stock: 10));
      final b = await productos.crear(_producto(sku: 'B-1', stock: 4));

      await productos.ajustarStock(a.id!, -2);
      await productos.ajustarStock(b.id!, 6);
      await inventario.registrarVarios([
        SolicitudMovimiento.salida(
          productoId: a.id!,
          cantidad: 3,
          tipo: TipoMovimiento.salidaVenta,
        ),
        SolicitudMovimiento.entrada(
          productoId: b.id!,
          cantidad: 1,
          tipo: TipoMovimiento.devolucionVenta,
        ),
      ]);

      expect(await inventario.descuadres(), isEmpty);
    });

    test('descuadres delata al que escribe el stock por fuera', () async {
      final creado = await productos.crear(_producto(stock: 10));

      // Justo lo que hacían los seis `UPDATE` repartidos por la app.
      await db.customStatement(
        'UPDATE productos SET stock_actual = stock_actual - 4 WHERE id = ?',
        [creado.id],
      );

      expect(await inventario.descuadres(), {creado.id!: -4.0});
    });
  });

  group('atomicidad', () {
    test('si una línea del lote falla, no se aplica ninguna', () async {
      final creado = await productos.crear(_producto(stock: 10));

      await expectLater(
        inventario.registrarVarios([
          SolicitudMovimiento.salida(
            productoId: creado.id!,
            cantidad: 3,
            tipo: TipoMovimiento.salidaVenta,
          ),
          // Producto inexistente: la FK lo rechaza y tumba la transacción.
          SolicitudMovimiento.salida(
            productoId: 9999,
            cantidad: 1,
            tipo: TipoMovimiento.salidaVenta,
          ),
        ]),
        throwsA(isA<Exception>()),
      );

      expect(await _stockCache(creado.id!), 10);
      expect(await inventario.stockReconstruido(creado.id!), 10);
    });
  });

  group('el kardex filtra, cuenta y recorta en SQL', () {
    test('trae el producto y el autor ya resueltos', () async {
      final creado = await productos.crear(_producto(stock: 10));

      final pagina = await inventario
          .observarPagina(
            filtro: const FiltroMovimientos(),
            pagina: 0,
            tamano: 20,
          )
          .first;

      expect(pagina.total, 1);
      expect(pagina.items.single.productoNombre, 'Pastilla');
      expect(pagina.items.single.productoSku, creado.sku);
      expect(pagina.items.single.usuario, 'Usuario de prueba');
      // Un ajuste de alta no viene de ningún documento.
      expect(pagina.items.single.numeroDocumento, isNull);
    });

    test('filtrar por quién movió deja fuera lo de los demás', () async {
      // `FiltroMovimientos.usuarioId` estaba resuelto en SQL y con su índice
      // desde la tanda de auditoría, y ninguna pantalla lo pedía: el kardex
      // no tenía el selector de cuentas. Ahora lo tiene, así que esto es la
      // consulta que ese desplegable dispara.
      final creado = await productos.crear(_producto(stock: 10));

      final otra = await sesionDePrueba(db, usuario: 'otro');
      await RepositorioProductosImpl(db, otra).ajustarStock(creado.id!, 3);

      final suyos = await inventario
          .observarPagina(
            filtro: FiltroMovimientos(usuarioId: otra.usuarioId),
            pagina: 0,
            tamano: 20,
          )
          .first;

      expect(suyos.total, 1, reason: 'el alta la firmó la otra sesión');
      expect(suyos.items.single.cantidad, 3);
      expect(suyos.items.single.usuario, 'Usuario de prueba');

      final todos = await inventario
          .observarPagina(
            filtro: const FiltroMovimientos(),
            pagina: 0,
            tamano: 20,
          )
          .first;
      expect(todos.total, 2);
    });

    test('el total es el real, no el recortado por el LIMIT', () async {
      final creado = await productos.crear(_producto(stock: 1));
      for (var i = 0; i < 6; i++) {
        await productos.ajustarStock(creado.id!, 1);
      }

      final pagina = await inventario
          .observarPagina(
            filtro: const FiltroMovimientos(),
            pagina: 0,
            tamano: 2,
          )
          .first;

      expect(pagina.items, hasLength(2));
      expect(pagina.total, 7);
    });

    test('filtrar por producto no trae los del otro', () async {
      final a = await productos.crear(_producto(sku: 'A-1', stock: 5));
      await productos.crear(_producto(sku: 'B-1', nombre: 'Aceite', stock: 5));

      final pagina = await inventario
          .observarPagina(
            filtro: FiltroMovimientos(productoId: a.id!),
            pagina: 0,
            tamano: 20,
          )
          .first;

      expect(pagina.total, 1);
      expect(pagina.items.single.productoSku, 'A-1');
    });

    test('soloEntradas sale del signo, no de una lista de tipos', () async {
      final creado = await productos.crear(_producto(stock: 10));
      await productos.ajustarStock(creado.id!, -4);

      final entradas = await inventario
          .observarPagina(
            filtro: const FiltroMovimientos(soloEntradas: true),
            pagina: 0,
            tamano: 20,
          )
          .first;
      final salidas = await inventario
          .observarPagina(
            filtro: const FiltroMovimientos(soloEntradas: false),
            pagina: 0,
            tamano: 20,
          )
          .first;

      expect(entradas.total, 1);
      expect(entradas.items.single.cantidad, 10);
      expect(salidas.total, 1);
      expect(salidas.items.single.cantidad, -4);
    });

    test('la búsqueda pega contra nombre, SKU y notas', () async {
      await productos.crear(_producto(sku: 'ACE-9', nombre: 'Aceite', stock: 3));

      for (final texto in ['Aceit', 'ACE-9', 'Alta del']) {
        final pagina = await inventario
            .observarPagina(
              filtro: FiltroMovimientos(busqueda: texto),
              pagina: 0,
              tamano: 20,
            )
            .first;
        expect(pagina.total, 1, reason: 'buscando «$texto»');
      }
    });

    test('sin INVENTARIO_MOVIMIENTOS_VER no se abre el kardex', () async {
      final sinPermiso = RepositorioInventarioImpl(
        db,
        await sesionDePrueba(
          db,
          permisos: {Permiso.productosVer},
          usuario: 'cajero',
        ),
      );

      expect(
        () => sinPermiso.observarPagina(
          filtro: const FiltroMovimientos(),
          pagina: 0,
          tamano: 20,
        ),
        throwsA(isA<PermisoDenegado>()),
      );
    });
  });

  group('entrada por compra', () {
    test('suma al stock y queda como ENTRADA_COMPRA', () async {
      final creado = await productos.crear(_producto(stock: 4));

      await inventario.registrarEntradaCompra(
        productoId: creado.id!,
        cantidad: 12,
        notas: 'Remisión 881',
      );

      final movimientos =
          await inventario.observarPorProducto(creado.id!).first;

      expect(await _stockCache(creado.id!), 16);
      expect(movimientos.first.tipo, TipoMovimiento.entradaCompra);
      expect(movimientos.first.cantidad, 12);
      expect(movimientos.first.notas, 'Remisión 881');
      expect(await inventario.descuadres(), isEmpty);
    });

    test('sin INVENTARIO_ENTRADA no se da entrada a nada', () async {
      final creado = await productos.crear(_producto(stock: 4));
      final sinPermiso = RepositorioInventarioImpl(
        db,
        await sesionDePrueba(
          db,
          permisos: {Permiso.productosVer},
          usuario: 'cajero',
        ),
      );

      expect(
        () => sinPermiso.registrarEntradaCompra(
          productoId: creado.id!,
          cantidad: 1,
        ),
        throwsA(isA<PermisoDenegado>()),
      );
      expect(await _stockCache(creado.id!), 4);
    });
  });

  group('el esquema es el que manda', () {
    test('un movimiento de cantidad cero no se admite', () async {
      final creado = await productos.crear(_producto());

      expect(
        () => inventario.registrar(
          SolicitudMovimiento(
            productoId: creado.id!,
            cantidad: 0,
            tipo: TipoMovimiento.ajustePositivo,
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('un movimiento no puede venir de dos documentos a la vez', () async {
      final creado = await productos.crear(_producto());

      expect(
        () => inventario.registrar(
          SolicitudMovimiento.salida(
            productoId: creado.id!,
            cantidad: 1,
            tipo: TipoMovimiento.salidaVenta,
            ventaId: 1,
            reservaId: 1,
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('no se puede borrar un producto con historial', () async {
      final creado = await productos.crear(_producto(stock: 5));

      expect(() => productos.eliminar(creado.id!), throwsA(isA<Exception>()));
    });

    test('el SKU es único aunque nadie lo valide en Dart', () async {
      await productos.crear(_producto(sku: 'FRE-1'));

      expect(
        () => productos.crear(_producto(sku: 'FRE-1', nombre: 'Otra')),
        throwsA(isA<Exception>()),
      );
    });

    test('un precio negativo se rechaza', () async {
      expect(
        () => productos.crear(_producto(precioVenta: -1)),
        throwsA(isA<Exception>()),
      );
    });
  });
}
