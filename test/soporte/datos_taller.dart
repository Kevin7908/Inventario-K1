import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

/// Filas mínimas para poder facturar: persona, cliente, moto, técnico,
/// servicio y producto.
///
/// Con las FK activas —y desde la normalización en `personas`— crear una
/// factura a mano exige media docena de inserciones encadenadas. Esto las
/// concentra en un sitio para que los tests hablen de lo que prueban.
class DatosTaller {
  const DatosTaller({
    required this.personaId,
    required this.clienteId,
    required this.motoId,
    required this.tecnicoId,
    required this.servicioId,
    required this.productoId,
    required this.marcaId,
    required this.modeloId,
  });

  final int personaId;
  final int clienteId;
  final int motoId;
  final int tecnicoId;
  final int servicioId;
  final int productoId;

  /// El catálogo detrás de [motoId]: «Bajaj» y «Bajaj Pulsar».
  final int marcaId;
  final int modeloId;
}

/// Siembra el taller y devuelve los ids.
///
/// [stockInicial] entra como movimiento de inventario, igual que en la app:
/// escribir `stock_actual` a mano dejaría el libro mayor descuadrado y los
/// tests de reconciliación en rojo por una razón falsa.
Future<DatosTaller> sembrarTaller(
  AppDb db, {
  double stockInicial = 10,
  int precioVenta = 30000,
  /// Quién firma el movimiento del stock inicial. `usuario_id` es `NOT NULL`
  /// en `movimientos_inventario`, así que hace falta una cuenta real; los
  /// tests la crean con `sesionDePrueba`.
  int? usuarioId,
}) async {
  final personaCliente = await db.into(db.tablaPersona).insert(
        TablaPersonaCompanion.insert(
          nombres: 'Carlos',
          apellidos: const Value('Ramírez'),
          documento: const Value('1098765432'),
        ),
      );
  final clienteId = await db
      .into(db.tablaCliente)
      .insert(TablaClienteCompanion.insert(personaId: personaCliente));

  // La marca y el modelo son catálogo, no texto: hay que darlos de alta antes
  // de que exista la moto (`REGLAS_BD.md` §1.3).
  final marcaId = await db
      .into(db.tablaMarcaMoto)
      .insert(TablaMarcaMotoCompanion.insert(nombre: 'Bajaj'));
  final modeloId = await db.into(db.tablaModeloMoto).insert(
        TablaModeloMotoCompanion.insert(marcaId: marcaId, nombre: 'Pulsar'),
      );

  final motoId = await db.into(db.tablaMoto).insert(
        TablaMotoCompanion.insert(
          clienteId: clienteId,
          marcaId: marcaId,
          modeloId: Value(modeloId),
          placa: const Value('KMN12C'),
        ),
      );

  final personaTecnico = await db.into(db.tablaPersona).insert(
        TablaPersonaCompanion.insert(
          nombres: 'Ana',
          apellidos: const Value('Torres'),
          documento: const Value('987654321'),
        ),
      );
  final tecnicoId = await db
      .into(db.tablaTecnico)
      .insert(TablaTecnicoCompanion.insert(personaId: personaTecnico));

  final servicioId = await db
      .into(db.tablaServicio)
      .insert(TablaServicioCompanion.insert(nombre: 'Sincronización'));

  final productoId = await db.into(db.tablaProducto).insert(
        TablaProductoCompanion.insert(
          sku: 'FRE-1',
          nombre: 'Pastilla de freno',
          precioVenta: Value(precioVenta),
          precioCompra: const Value(18000),
        ),
      );

  if (stockInicial != 0) {
    await db.into(db.tablaMovimientoInventario).insert(
          TablaMovimientoInventarioCompanion.insert(
            usuarioId: usuarioId ?? await _cuentaDeSiembra(db),
            productoId: productoId,
            tipo: 'AJUSTE_INICIAL',
            cantidad: stockInicial,
          ),
        );
    await db.customStatement(
      'UPDATE productos SET stock_actual = ? WHERE id = ?',
      [stockInicial, productoId],
    );
  }

  return DatosTaller(
    personaId: personaCliente,
    clienteId: clienteId,
    motoId: motoId,
    tecnicoId: tecnicoId,
    servicioId: servicioId,
    productoId: productoId,
    marcaId: marcaId,
    modeloId: modeloId,
  );
}

/// La cuenta que firma el sembrado cuando el test no pasa la suya.
///
/// Reutiliza la primera que haya —los tests crean la suya con
/// `sesionDePrueba` antes de sembrar— y solo inventa una si no hay ninguna,
/// para que un test que no necesita sesión siga funcionando.
Future<int> _cuentaDeSiembra(AppDb db) async {
  final existente = await db.select(db.tablaUsuario).getSingleOrNull();
  if (existente != null) return existente.id;

  final personaId = await db
      .into(db.tablaPersona)
      .insert(TablaPersonaCompanion.insert(nombres: 'Siembra'));

  return db.into(db.tablaUsuario).insert(
        TablaUsuarioCompanion.insert(
          personaId: personaId,
          usuario: 'siembra',
          passwordHash: 'hash-de-prueba',
        ),
      );
}
