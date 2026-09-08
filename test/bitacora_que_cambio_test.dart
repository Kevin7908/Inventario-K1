// «Últimos cambios» tiene que decir qué cambió, no solo que alguien tocó algo.
//
// El panel de la ficha existía desde la tanda de auditoría y decía «Ana
// modificó Pastilla de freno (FRE-0012)» y nada más, que no responde la
// pregunta con la que se abre ese panel: por qué subió el precio, quién movió
// el stock mínimo. Y además **no se refrescaba**: el provider era un `Future`
// que nadie invalidaba, así que después de guardar seguía diciendo que nadie
// había tocado la ficha.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/bitacora/modelo/entrada_bitacora.dart';
import 'package:inventario_k1/backend/features/bitacora/repositorio/repositorio_bitacora_impl.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/features/productos/repositorio/repositorio_producto_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/sesion_de_prueba.dart';

late AppDb db;
late SesionActual sesion;
late RepositorioProductosImpl productos;
late RepositorioBitacoraImpl bitacora;

Producto _nuevo() => const Producto(
      nombre: 'Pastilla de freno',
      sku: 'FRE-0012',
      precioCompra: 15000,
      precioVenta: 28000,
      stockActual: 10,
      stockMinimo: 2,
      ubicacionBodega: 'A-01',
      activo: true,
    );

/// El detalle del último renglón de la bitácora de ese producto.
Future<String?> _ultimoDetalle(int productoId) async {
  final entradas = await bitacora.historialDe(
    EntidadAuditada.producto,
    productoId,
    limite: 1,
  );
  return entradas.single.detalle;
}

void main() {
  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
    productos = RepositorioProductosImpl(db, sesion);
    bitacora = RepositorioBitacoraImpl(db, sesion);
  });

  tearDown(() => db.close());

  test('el renglón dice qué campo cambió y de cuánto a cuánto', () async {
    final creado = await productos.crear(_nuevo());
    await productos.actualizar(creado.copyWith(precioVenta: 32000));

    expect(
      await _ultimoDetalle(creado.id!),
      'Precio de venta: \$28.000 → \$32.000',
    );
  });

  test('varios cambios a la vez caben en el mismo renglón', () async {
    final creado = await productos.crear(_nuevo());
    await productos.actualizar(
      creado.copyWith(
        nombre: 'Pastilla de freno trasera',
        precioVenta: 32000,
        ubicacionBodega: 'B-04',
      ),
    );

    final detalle = await _ultimoDetalle(creado.id!);
    expect(detalle, contains('Nombre: Pastilla de freno → Pastilla de freno trasera'));
    expect(detalle, contains('Precio de venta: \$28.000 → \$32.000'));
    expect(detalle, contains('Ubicación: A-01 → B-04'));
  });

  test('el stock se nombra como ajuste, no como columna reescrita', () async {
    // El stock no se escribe: se registra como movimiento (`REGLAS_BD.md` §7).
    // El renglón lo dice así para que nadie lo busque en la columna.
    final creado = await productos.crear(_nuevo());
    await productos.actualizar(creado.copyWith(stockActual: 14));

    expect(await _ultimoDetalle(creado.id!), 'Stock ajustado en +4');
  });

  test('guardar sin tocar nada no inventa un cambio', () async {
    final creado = await productos.crear(_nuevo());
    await productos.actualizar(creado);

    expect(await _ultimoDetalle(creado.id!), isNull);
  });

  test('el historial de la ficha se puede observar en vivo', () async {
    // Es lo que hace que el panel se entere sin que nadie lo invalide.
    final creado = await productos.crear(_nuevo());
    // El `expectLater` se lanza **sin esperarlo** y la escritura va después:
    // al revés el test se cuelga, porque `expectLater` no devuelve hasta que
    // el stream emita y el stream no emite hasta que alguien escriba.
    final espera = expectLater(
      bitacora.observarHistorialDe(EntidadAuditada.producto, creado.id!),
      emitsThrough(predicate<List<EntradaBitacora>>(
        (lista) => lista.any(
          (e) => e.detalle == 'Precio de venta: \$28.000 → \$32.000',
        ),
        'emite el cambio de precio sin que nadie reabra la consulta',
      )),
    );

    await productos.actualizar(creado.copyWith(precioVenta: 32000));
    await espera;
  });
}
