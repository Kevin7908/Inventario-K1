// El catálogo completo se suelta cuando nadie lo está mirando.
//
// `catalogoCompletoProvider` trae el inventario entero con cinco tablas
// unidas, y lo observan los buscadores de los editores de orden, cotización,
// reserva y deuda. Mientras fue un provider global, abrir **una vez** cualquier
// editor dejaba esa consulta viva hasta cerrar sesión: Drift la volvía a
// correr completa ante cualquier cambio en productos, categorías o
// proveedores, y cada venta del mostrador mueve `stock_actual`.
//
// Lo que se prueba es la disposición, no el contenido: que al cerrar el último
// oyente el provider deje de existir en el contenedor. Con `.autoDispose`
// quitado, `exists` sigue devolviendo `true` y este test falla.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/database/app_db_provider.dart';
import 'package:inventario_k1/frontend/features/autenticacion/provider/auth_providers.dart';
import 'package:inventario_k1/frontend/features/productos/provider/productos_provider.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/sesion_de_prueba.dart';

void main() {
  late AppDb db;
  late ProviderContainer container;

  setUp(() async {
    db = baseEnMemoria();
    final sesion = await sesionDePrueba(db);
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sesionActualProvider.overrideWithValue(sesion),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('cerrar el último editor suelta el catálogo y su consulta', () async {
    // Un editor abierto: alguien observa el catálogo.
    final editor = container.listen(catalogoCompletoProvider, (_, _) {});
    expect(
      container.exists(catalogoCompletoProvider),
      isTrue,
      reason: 'con un oyente el catálogo tiene que estar vivo',
    );

    // Se cierra el editor. La disposición no es inmediata: Riverpod la agenda,
    // así que hay que dejar correr la cola de eventos antes de preguntar.
    editor.close();
    await Future<void>.delayed(Duration.zero);

    expect(
      container.exists(catalogoCompletoProvider),
      isFalse,
      reason: 'sin oyentes no puede quedar viva una consulta de cinco tablas '
          'que se re-ejecuta con cada movimiento de stock',
    );
  });

  test('dos editores abiertos comparten la misma consulta', () async {
    // Es la otra mitad de la decisión: `autoDispose` no significa una consulta
    // por pantalla. Mientras quede un oyente, el catálogo sigue siendo uno.
    final orden = container.listen(catalogoCompletoProvider, (_, _) {});
    final cotizacion = container.listen(catalogoCompletoProvider, (_, _) {});

    orden.close();
    await Future<void>.delayed(Duration.zero);

    expect(
      container.exists(catalogoCompletoProvider),
      isTrue,
      reason: 'el segundo editor todavía lo está mirando',
    );

    cotizacion.close();
    await Future<void>.delayed(Duration.zero);

    expect(container.exists(catalogoCompletoProvider), isFalse);
  });
}
