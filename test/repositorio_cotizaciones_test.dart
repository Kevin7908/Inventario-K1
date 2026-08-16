// Paginación, filtro por estado y resumen del repositorio de cotizaciones.
//
// Corre contra una base SQLite en memoria. Lo que más importa comprobar aquí es
// que el **estado** (vigente / por vencer / vencida) se resuelve en SQL
// comparando `vigencia_hasta` con la fecha de hoy: antes se calculaba en Dart
// recorriendo la lista entera, así que ni el filtro ni el conteo podían
// apoyarse en él.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/clientes/modelo/cliente.dart';
import 'package:inventario_k1/backend/features/clientes/repositorio/repositorio_cliente_impl.dart';
import 'package:inventario_k1/backend/features/cotizaciones/enum/enum_cotizacion.dart';
import 'package:inventario_k1/backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import 'package:inventario_k1/backend/features/cotizaciones/repositorio/repositorio_cotizaciones.dart';
import 'package:inventario_k1/backend/features/cotizaciones/repositorio/repositorio_cotizaciones_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/core/iva_app.dart';

late AppDb db;
late RepositorioCotizacionesImpl repo;
late RepositorioClientesImpl clientes;

/// Fecha a [dias] de hoy, en el formato 'YYYY-MM-DD' que guarda la columna.
String _enDias(int dias) {
  final f = DateTime.now().add(Duration(days: dias));
  return '${f.year}-${f.month.toString().padLeft(2, '0')}-'
      '${f.day.toString().padLeft(2, '0')}';
}

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
  setUp(() {
    db = AppDb(NativeDatabase.memory());
    repo = RepositorioCotizacionesImpl(db);
    clientes = RepositorioClientesImpl(db);
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

  group('tipos de ítem', () {
    test('guarda servicios y líneas libres, no solo productos', () async {
      final id = await repo.crear(
        vigenciaHasta: _enDias(30),
        items: const [
          ItemDraft(
            tipo: TipoItemCotizacion.producto,
            referenciaId: 7,
            descripcion: 'Aceite 20W50',
            cantidad: 2,
            precioUnitario: 32000,
          ),
          ItemDraft(
            tipo: TipoItemCotizacion.servicio,
            referenciaId: 3,
            descripcion: 'Cambio de aceite',
            cantidad: 1,
            precioUnitario: 25000,
          ),
          ItemDraft(
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
}
