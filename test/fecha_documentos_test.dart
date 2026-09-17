import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/ordenes/repositorio/repositorio_ordenes.dart';
import 'package:inventario_k1/backend/features/ordenes/repositorio/repositorio_ordenes_impl.dart';
import 'package:inventario_k1/backend/features/pos/enum/enum_ventas.dart';
import 'package:inventario_k1/backend/features/pos/modelo/linea_venta_mostrador.dart';
import 'package:inventario_k1/backend/features/pos/repositorio/repositorio_ventas_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/datos_taller.dart';
import 'soporte/sesion_de_prueba.dart';

/// La fecha de una venta y la de una orden salían siempre en 1970.
///
/// Las dos se leen de un `customSelect`, así que llegan como el entero crudo
/// de SQLite —y Drift guarda `DateTime` en **segundos**, no en milisegundos—.
/// Interpretarlo como milisegundos convierte 1.788 millones de segundos en
/// veinte días: 21/01/1970, la misma fecha para todos los documentos.
///
/// Los mappers de devoluciones y de inventario ya multiplicaban por 1000; los
/// de ventas y órdenes, no.
late AppDb db;
late SesionActual sesion;
late DatosTaller taller;

void main() {
  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
    taller = await sembrarTaller(db);
  });

  tearDown(() => db.close());

  test('la venta recién registrada se lee con la fecha de hoy', () async {
    final repo = RepositorioVentasImpl(db, sesion);
    final antes = DateTime.now().subtract(const Duration(minutes: 1));

    await repo.registrarVentaMostrador(
      clienteId: taller.clienteId,
      metodoPago: MetodoPago.efectivo,
      lineas: [
        LineaVentaMostrador(
          productoId: taller.productoId,
          descripcion: 'Pastilla de freno',
          cantidad: 1,
          precioUnitario: 30000,
          costoUnitario: 18000,
        ),
      ],
    );

    final resumenes = await repo.observarTodas().first;
    final creado = resumenes.single.creadoEn;

    expect(creado, isNotNull);
    expect(
      creado!.isAfter(antes),
      isTrue,
      reason: 'salió $creado: la fecha se está leyendo como milisegundos',
    );
  });

  test('la orden recién creada se lee con la fecha de hoy', () async {
    final repo = RepositorioOrdenesImpl(db, sesion);
    final antes = DateTime.now().subtract(const Duration(minutes: 1));

    await repo.agregar(
      motoId: taller.motoId,
      clienteId: taller.clienteId,
      kilometrajeEntrada: 12000,
    );

    final pagina = await repo
        .observarPagina(filtro: const FiltroOrdenes(), pagina: 0, tamano: 10)
        .first;
    final creado = pagina.items.single.fechaIngreso;

    expect(creado, isNotNull);
    expect(
      creado!.isAfter(antes),
      isTrue,
      reason: 'salió $creado: la fecha se está leyendo como milisegundos',
    );
  });
}
