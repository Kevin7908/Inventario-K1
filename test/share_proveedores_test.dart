// Widgets agregados o extendidos al migrar Proveedores a share.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/compras/repositorio/repositorio_compras.dart';
import 'package:inventario_k1/backend/features/proveedores/modelo/proveedor.dart';
import 'package:inventario_k1/frontend/features/compras/provider/compras_providers.dart';
import 'package:inventario_k1/frontend/features/proveedores/widgets/tarjeta_proveedor.dart';
import 'package:inventario_k1/frontend/share/share.dart';
import 'package:inventario_k1/frontend/features/proveedores/widgets/identidad_proveedor.dart';

/// La tarjeta del proveedor lleva desde las compras una línea con lo que se le
/// lleva comprado, y esa línea observa un provider: de ahí el `ProviderScope`.
///
/// El resumen llega **por override y síncrono**: la consulta real es un stream
/// de Drift, que bajo el `fakeAsync` de `flutter_test` no avanza y deja un
/// timer pendiente. Lo que se prueba aquí es la tarjeta; que la consulta sume
/// bien lo cubre `repositorio_compras_test.dart`.
Widget _envolver(Widget child, {ResumenProveedorCompras? compras}) =>
    ProviderScope(
      overrides: [
        resumenProveedorComprasProvider(1).overrideWith(
          (ref) => Stream.value(
            compras ??
                (
                  comprasMes: 0,
                  invertidoMes: 0,
                  invertidoTotal: 0,
                  ultimaCompra: null,
                ),
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(width: 360, child: child),
          ),
        ),
      ),
    );

Proveedor _proveedor({
  String nombre = 'Distrimotos S.A.',
  String? nit = '900.123.456-7',
  String? contacto = 'Carlos Méndez',
  String? telefono = '3001234567',
  String? ciudad = 'Bogotá',
  bool activo = true,
}) =>
    Proveedor(
      id: 1,
      nombre: nombre,
      nitCedula: nit,
      contacto: contacto,
      telefono: telefono,
      ciudad: ciudad,
      activo: activo,
    );

void main() {
  group('FilaDato', () {
    testWidgets('pinta el ícono junto al texto', (tester) async {
      await tester.pumpWidget(_envolver(
        const FilaDato(
          icono: Icons.person_outline_rounded,
          texto: 'Carlos Méndez',
        ),
      ));

      final icono = tester.getCenter(find.byIcon(Icons.person_outline_rounded));
      final texto = tester.getCenter(find.text('Carlos Méndez'));

      expect(icono.dx, lessThan(texto.dx));
      expect((icono.dy - texto.dy).abs(), lessThan(6));
    });

    testWidgets('destacado sube el peso y tiñe también el ícono',
        (tester) async {
      await tester.pumpWidget(_envolver(
        const FilaDato(
          icono: Icons.inventory_2_outlined,
          texto: '24 productos',
          color: ColoresApp.castletonGreen,
          destacado: true,
        ),
      ));

      final texto = tester.widget<Text>(find.text('24 productos'));
      expect(texto.style?.fontWeight, FontWeight.w600);
      expect(texto.style?.color, ColoresApp.castletonGreen);

      final icono = tester.widget<Icon>(find.byIcon(Icons.inventory_2_outlined));
      expect(
        icono.color,
        ColoresApp.castletonGreen,
        reason: 'sin destacar el ícono va en gris tenue',
      );
    });
  });

  group('TarjetaCatalogo con pie', () {
    testWidgets('el pie va debajo del título, no a su lado', (tester) async {
      await tester.pumpWidget(_envolver(
        const TarjetaCatalogo(
          icono: Icons.local_shipping_outlined,
          titulo: 'Distrimotos',
          pie: Text('NIT 900.123.456-7'),
        ),
      ));

      final titulo = tester.getCenter(find.text('Distrimotos'));
      final pie = tester.getCenter(find.text('NIT 900.123.456-7'));

      expect(pie.dy, greaterThan(titulo.dy));
    });

    testWidgets('sin pie la tarjeta no reserva espacio de más',
        (tester) async {
      await tester.pumpWidget(_envolver(
        const TarjetaCatalogo(
          icono: Icons.local_shipping_outlined,
          titulo: 'Distrimotos',
        ),
      ));
      final sinPie = tester.getSize(find.byType(TarjetaCatalogo)).height;

      await tester.pumpWidget(_envolver(
        const TarjetaCatalogo(
          icono: Icons.local_shipping_outlined,
          titulo: 'Distrimotos',
          pie: Text('NIT 900.123.456-7'),
        ),
      ));
      final conPie = tester.getSize(find.byType(TarjetaCatalogo)).height;

      expect(conPie, greaterThan(sinPie));
    });
  });

  group('TarjetaProveedor', () {
    testWidgets('muestra nombre, NIT, contacto y productos que surte',
        (tester) async {
      await tester.pumpWidget(_envolver(
        TarjetaProveedor(proveedor: _proveedor(), productos: 24),
      ));

      expect(find.text('Distrimotos S.A.'), findsOneWidget);
      expect(find.text('NIT 900.123.456-7'), findsOneWidget);
      expect(find.text('Carlos Méndez'), findsOneWidget);
      expect(find.text('3001234567'), findsOneWidget);
      expect(find.text('Bogotá'), findsOneWidget);
      expect(find.text('24 productos'), findsOneWidget);
    });

    testWidgets('los campos opcionales vacíos no dejan líneas en blanco',
        (tester) async {
      await tester.pumpWidget(_envolver(
        TarjetaProveedor(
          proveedor: _proveedor(nit: null, contacto: null, ciudad: null),
          productos: 0,
        ),
      ));

      expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.location_on_outlined), findsNothing);
      expect(find.textContaining('NIT'), findsNothing);
      expect(find.text('3001234567'), findsOneWidget);
      expect(find.text('0 productos'), findsOneWidget);
    });

    testWidgets('singulariza el conteo de un solo producto', (tester) async {
      await tester.pumpWidget(_envolver(
        TarjetaProveedor(proveedor: _proveedor(), productos: 1),
      ));

      expect(find.text('1 producto'), findsOneWidget);
    });

    testWidgets('el inactivo se marca; el activo no lleva badge',
        (tester) async {
      await tester.pumpWidget(_envolver(
        TarjetaProveedor(proveedor: _proveedor(), productos: 3),
      ));
      expect(find.text('Inactivo'), findsNothing);

      await tester.pumpWidget(_envolver(
        TarjetaProveedor(
          proveedor: _proveedor(activo: false),
          productos: 3,
        ),
      ));
      expect(find.text('Inactivo'), findsOneWidget);
    });

    testWidgets('todos los proveedores llevan el mismo almacén',
        (tester) async {
      // La apariencia dejó de ser un dato del proveedor: se elegía al crearlo
      // y dejaba el diseño de la app a merced de lo que alguien hubiera
      // tecleado. Ahora sale de `IdentidadProveedor`, en un solo sitio.
      await tester.pumpWidget(_envolver(
        TarjetaProveedor(proveedor: _proveedor(), productos: 3),
      ));

      expect(find.byIcon(IdentidadProveedor.icono), findsOneWidget);
    });

    testWidgets('avisa de editar y eliminar por separado', (tester) async {
      var editados = 0;
      var eliminados = 0;

      await tester.pumpWidget(_envolver(
        TarjetaProveedor(
          proveedor: _proveedor(),
          productos: 3,
          alEditar: () => editados++,
          alEliminar: () => eliminados++,
        ),
      ));

      await tester.tap(find.byTooltip('Editar'));
      await tester.tap(find.byTooltip('Eliminar'));

      expect(editados, 1);
      expect(eliminados, 1);
    });
  });

  group('lo que se le lleva comprado al proveedor', () {
    testWidgets('sin remisiones registradas lo dice', (tester) async {
      await tester.pumpWidget(_envolver(
        TarjetaProveedor(proveedor: _proveedor(), productos: 3),
      ));
      await tester.pump();

      expect(find.text('Sin compras registradas'), findsOneWidget);
    });

    testWidgets('con compras muestra lo del mes y cuándo fue la última',
        (tester) async {
      // Es la tercera pregunta que el taller hace todos los meses y que la app
      // no podía contestar mientras dar entrada fuera producto + cantidad.
      await tester.pumpWidget(_envolver(
        TarjetaProveedor(proveedor: _proveedor(), productos: 3),
        compras: (
          comprasMes: 2,
          invertidoMes: 1240000,
          invertidoTotal: 4300000,
          ultimaCompra: DateTime.now().subtract(const Duration(days: 12)),
        ),
      ));
      await tester.pump();

      expect(
        find.text(r'$1.240.000 este mes · la última hace 12 días'),
        findsOneWidget,
      );
    });
  });

  group('colorDeHex', () {
    test('convierte un hex válido y rechaza el resto', () {
      expect(colorDeHex('#01B763'), const Color(0xFF01B763));
      expect(colorDeHex('01B763'), const Color(0xFF01B763));
      expect(colorDeHex('#01B'), isNull, reason: 'longitud incorrecta');
      expect(colorDeHex('#ZZZZZZ'), isNull, reason: 'no es hexadecimal');
    });

    test('inicialDe toma la primera letra en mayúscula', () {
      expect(inicialDe('frenos'), 'F');
      expect(inicialDe('  motor'), 'M');
      expect(inicialDe('   '), '');
    });
  });
}
