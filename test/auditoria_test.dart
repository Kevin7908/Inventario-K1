// Quién hizo qué.
//
// Son dos mecanismos y prueban cosas distintas:
//
// - la columna `usuario_id` dice **quién creó** un documento o movió stock, y
//   es `NOT NULL`, así que la base no deja escribir sin firma;
// - la `bitacora` dice **quién editó o borró**, que es lo único que una
//   columna no puede contar: cuando la fila se va, su columna se va con ella.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/bitacora/modelo/entrada_bitacora.dart';
import 'package:inventario_k1/backend/features/bitacora/repositorio/repositorio_bitacora.dart';
import 'package:inventario_k1/backend/features/bitacora/repositorio/repositorio_bitacora_impl.dart';
import 'package:inventario_k1/backend/features/inventario/modelo/movimiento_inventario.dart';
import 'package:inventario_k1/backend/features/ordenes/enum/enum_ordenes.dart';
import 'package:inventario_k1/backend/features/ordenes/repositorio/repositorio_ordenes_impl.dart';
import 'package:inventario_k1/backend/features/inventario/repositorio/repositorio_inventario_impl.dart';
import 'package:inventario_k1/backend/features/pos/modelo/linea_venta_mostrador.dart';
import 'package:inventario_k1/backend/features/pos/repositorio/repositorio_ventas_impl.dart';
import 'package:inventario_k1/backend/features/productos/modelo/producto.dart';
import 'package:inventario_k1/backend/features/productos/repositorio/repositorio_producto_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/metodo_pago.dart';
import 'package:inventario_k1/backend/share/dominio/permiso.dart';
import 'package:inventario_k1/backend/share/dominio/rol_usuario.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/datos_taller.dart';
import 'soporte/sesion_de_prueba.dart';

late AppDb db;

/// Quien firma lo que escriben estos tests. Ver `sesionDePrueba`.
late SesionActual sesion;

late RepositorioProductosImpl productos;
late RepositorioBitacoraImpl bitacora;
late DatosTaller taller;

Producto _producto({String sku = 'ACE-1', String nombre = 'Aceite 20W50'}) =>
    Producto(
      sku: sku,
      nombre: nombre,
      precioCompra: 25000,
      precioVenta: 40000,
      stockActual: 0,
      stockMinimo: 0,
      aplicaIva: true,
      activo: true,
    );

void main() {
  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
    productos = RepositorioProductosImpl(db, sesion);
    bitacora = RepositorioBitacoraImpl(db, sesion);
    taller = await sembrarTaller(db, usuarioId: sesion.usuarioId);
  });

  tearDown(() => db.close());

  group('la columna dice quién lo creó', () {
    test('una venta de mostrador queda firmada', () async {
      final ventas = RepositorioVentasImpl(db, sesion);
      final venta = await ventas.registrarVentaMostrador(
        lineas: [
          LineaVentaMostrador(
            productoId: taller.productoId,
            descripcion: 'Pastilla de freno',
            cantidad: 1,
            precioUnitario: 30000,
            costoUnitario: 18000,
          ),
        ],
        metodoPago: MetodoPago.efectivo,
      );

      final fila = await (db.select(db.tablaVentas)
            ..where((v) => v.id.equals(venta.id)))
          .getSingle();

      expect(fila.usuarioId, sesion.usuarioId);
    });

    test('todo movimiento de inventario queda firmado', () async {
      await productos.ajustarStock(taller.productoId, 5);

      final movimientos = await db.select(db.tablaMovimientoInventario).get();
      expect(movimientos, isNotEmpty);
      expect(
        movimientos.every((m) => m.usuarioId == sesion.usuarioId),
        isTrue,
        reason: 'ningún movimiento puede quedarse sin autor',
      );
    });

    test('sin sesión no se puede escribir: la firma no es opcional', () async {
      final anonimo = RepositorioInventarioImpl(db, null);

      expect(
        () => anonimo.registrar(
          SolicitudMovimiento(
            productoId: taller.productoId,
            cantidad: 1,
            tipo: TipoMovimiento.ajustePositivo,
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('la bitácora dice quién lo editó o lo borró', () {
    test('crear un producto deja su renglón con el nombre y el SKU', () async {
      final creado = await productos.crear(_producto());

      final pagina = await bitacora
          .observarPagina(
            filtro: const FiltroBitacora(entidad: EntidadAuditada.producto),
            pagina: 0,
            tamano: 10,
          )
          .first;

      final renglon = pagina.items.first;
      expect(renglon.accion, AccionAuditada.creo);
      expect(renglon.entidadId, creado.id);
      expect(renglon.descripcion, 'Aceite 20W50 (ACE-1)');
      expect(renglon.usuarioId, sesion.usuarioId);
      expect(renglon.nombreUsuario, 'Usuario de prueba');
    });

    test('el renglón del borrado sobrevive al producto', () async {
      // Es lo único que una columna `usuario_id` no puede contar: cuando la
      // fila desaparece, se lleva su columna.
      final creado = await productos.crear(_producto());
      await productos.eliminar(creado.id!);

      expect(await productos.obtenerPorId(creado.id!), isNull);

      final pagina = await bitacora
          .observarPagina(
            filtro: const FiltroBitacora(accion: AccionAuditada.elimino),
            pagina: 0,
            tamano: 10,
          )
          .first;

      expect(pagina.total, 1);
      expect(pagina.items.single.descripcion, 'Aceite 20W50 (ACE-1)');
    });

    test('editar deja MODIFICO, y el historial de la fila los trae los dos',
        () async {
      final creado = await productos.crear(_producto());
      await productos.actualizar(
        creado.copyWith(nombre: 'Aceite 20W50 sintético'),
      );

      final historial = await bitacora.historialDe(
        EntidadAuditada.producto,
        creado.id!,
      );

      expect(historial.map((e) => e.accion), [
        AccionAuditada.modifico,
        AccionAuditada.creo,
      ]);
    });

    test('el ajuste manual de stock anota cuánto se movió', () async {
      await productos.ajustarStock(taller.productoId, -3);

      final historial = await bitacora.historialDe(
        EntidadAuditada.producto,
        taller.productoId,
      );

      expect(historial.single.detalle, contains('-3'));
    });

    test('el filtro por usuario y el total salen de SQL', () async {
      final otra = await sesionDePrueba(db, usuario: 'otro');
      final suyos = RepositorioProductosImpl(db, otra);

      await productos.crear(_producto(sku: 'A-1', nombre: 'Uno'));
      await suyos.crear(_producto(sku: 'A-2', nombre: 'Dos'));
      await suyos.crear(_producto(sku: 'A-3', nombre: 'Tres'));

      final pagina = await bitacora
          .observarPagina(
            filtro: FiltroBitacora(usuarioId: otra.usuarioId),
            pagina: 0,
            tamano: 1,
          )
          .first;

      // El total no lo recorta el `LIMIT`: son dos aunque venga una sola.
      expect(pagina.items, hasLength(1));
      expect(pagina.total, 2);
    });

    test('la búsqueda mira la descripción', () async {
      await productos.crear(_producto(sku: 'A-1', nombre: 'Filtro de aire'));
      await productos.crear(_producto(sku: 'A-2', nombre: 'Bujía'));

      final pagina = await bitacora
          .observarPagina(
            filtro: const FiltroBitacora(busqueda: 'bujía'),
            pagina: 0,
            tamano: 10,
          )
          .first;

      expect(pagina.total, 1);
      expect(pagina.items.single.descripcion, contains('Bujía'));
    });
  });

  group('cerrar o anular una orden deja rastro de quién fue', () {
    // `ordenes_servicio.usuario_id` dice quién la **abrió** y nada más. Cerrar
    // le pone precio al trabajo y anular devuelve los repuestos al estante:
    // son los dos gestos que valen plata, y hasta ahora no constaban.

    late RepositorioOrdenesImpl ordenes;
    late int ordenId;

    setUp(() async {
      ordenes = RepositorioOrdenesImpl(db, sesion);
      final orden = await ordenes.agregar(
        motoId: taller.motoId,
        clienteId: taller.clienteId,
        kilometrajeEntrada: 12000,
      );
      ordenId = orden.id;
    });

    Future<void> pasarA(EstadoOrden estado) => ordenes.actualizar(
          id: ordenId,
          estado: estado,
          kilometrajeEntrada: 12000,
        );

    Future<List<EntradaBitacora>> historial() =>
        bitacora.historialDe(EntidadAuditada.orden, ordenId);

    test('cerrarla queda anotado, con el estado de dónde a dónde', () async {
      await pasarA(EstadoOrden.lista);

      final renglon = (await historial()).single;
      expect(renglon.accion, AccionAuditada.modifico);
      expect(renglon.usuarioId, sesion.usuarioId);
      expect(renglon.detalle, 'Estado: Abierta → Lista');
    });

    test('anularla se anota como anulación, no como edición', () async {
      // Quien revisa la caja tiene que distinguir de un vistazo la orden que
      // se deshizo de la que solo cambió de mano.
      await pasarA(EstadoOrden.anulada);

      expect((await historial()).single.accion, AccionAuditada.anulo);
    });

    test('guardar la cabecera sin mover el estado no anota nada', () async {
      // `actualizar` es también el autoguardado: un renglón por pasada
      // llenaría la bitácora de ruido mientras alguien teclea el diagnóstico.
      await ordenes.actualizar(
        id: ordenId,
        estado: EstadoOrden.abierta,
        kilometrajeEntrada: 12500,
        diagnostico: 'Suena la cadena',
      );

      expect(await historial(), isEmpty);
    });
  });

  group('la bitácora se poda, pero no se puede tapar nada con eso', () {
    // Crece un renglón por cada alta, edición y borrado de catálogo, y no
    // tenía nada que la recortara. Ahora sí, con un piso: los últimos dos años
    // no los borra nadie, ni desde la app ni abriendo el `.sqlite` a mano.

    /// Envejece a la fuerza lo anotado, para no depender del reloj ni tener
    /// que esperar dos años. Es un `UPDATE` sobre la bitácora, que su guarda
    /// prohíbe, así que hay que quitarla y devolverla.
    ///
    /// El `CAST(... AS INTEGER)` es obligatorio: Drift guarda las fechas como
    /// segundos de época, y escribir ahí el texto de `datetime('now', …)`
    /// dejaría la columna con un valor que ninguna comparación entiende.
    Future<void> envejecer(int meses) async {
      await db.customStatement('DROP TRIGGER guarda_bitacora_inmutable');
      await db.customStatement(
        "UPDATE bitacora SET creado_en = "
        "CAST(strftime('%s', 'now', ?) AS INTEGER)",
        ['-$meses months'],
      );
      await db.customStatement('''
        CREATE TRIGGER guarda_bitacora_inmutable
        BEFORE UPDATE ON bitacora
        FOR EACH ROW
        BEGIN
          SELECT RAISE(ABORT, 'La bitácora no se edita.');
        END;
      ''');
    }

    test('lo viejo se va y deja dicho cuánto se fue', () async {
      await productos.crear(_producto());
      await envejecer(30);

      expect(await bitacora.cuantasPodaria(meses: 24), 1);
      expect(await bitacora.podar(meses: 24), 1);

      // La poda deja **su propio** renglón: sería el único acto de la app sin
      // rastro, y justo el que serviría para tapar los demás.
      final quedan = await bitacora
          .observarPagina(
            filtro: const FiltroBitacora(),
            pagina: 0,
            tamano: 10,
          )
          .first;

      expect(quedan.total, 1);
      expect(quedan.items.single.accion, AccionAuditada.elimino);
      expect(quedan.items.single.detalle, contains('1 anotaciones'));
    });

    test('lo reciente no se va, aunque se pidan doce meses', () async {
      await productos.crear(_producto());
      await envejecer(18);

      // El piso son dos años y el repositorio recorta: pedir doce meses no
      // borra de menos, no revienta contra la guarda.
      expect(await bitacora.podar(meses: 12), 0);
      expect(await bitacora.cuantasPodaria(meses: 12), 0);
    });

    test('la guarda de la base rechaza el borrado de lo reciente', () async {
      // El repositorio recorta, pero la garantía es ésta: quien abra el
      // `.sqlite` con un visor tampoco puede.
      await productos.crear(_producto());

      expect(
        db.customStatement('DELETE FROM bitacora'),
        throwsA(anything),
      );
    });

    test('podar no lo puede hacer cualquiera que la lea', () async {
      // Recortarla no es leerla: es el gesto con el que se taparía lo demás.
      final auditor = RepositorioBitacoraImpl(
        db,
        SesionActual(
          usuarioId: sesion.usuarioId,
          rol: RolUsuario.cajero,
          permisos: const {Permiso.bitacoraVer},
        ),
      );

      await expectLater(
        auditor.podar(meses: 24),
        throwsA(isA<PermisoDenegado>()),
      );
    });
  });

  group('la bitácora no se corrige', () {
    test('no se edita', () async {
      await productos.crear(_producto());

      // Quien quisiera tapar lo que hizo empezaría por su propio renglón: la
      // única defensa que vale es que la base no se lo permita a nadie.
      expect(
        db.customStatement(
          "UPDATE bitacora SET descripcion = 'otra cosa'",
        ),
        throwsA(anything),
      );
    });

    test('no se borra', () async {
      await productos.crear(_producto());

      expect(
        db.customStatement('DELETE FROM bitacora'),
        throwsA(anything),
      );
    });
  });

  group('lo anotado se revierte con su transacción', () {
    test('un alta que falla no deja renglón', () async {
      await productos.crear(_producto(sku: 'REP-1'));

      // El segundo choca contra el `UNIQUE` del SKU.
      await expectLater(
        productos.crear(_producto(sku: 'REP-1', nombre: 'Otro')),
        throwsA(anything),
      );

      final pagina = await bitacora
          .observarPagina(
            filtro: const FiltroBitacora(entidad: EntidadAuditada.producto),
            pagina: 0,
            tamano: 10,
          )
          .first;

      expect(
        pagina.total,
        1,
        reason: 'una bitácora que cuenta cosas que no pasaron es peor que '
            'no tenerla',
      );
    });
  });
}
