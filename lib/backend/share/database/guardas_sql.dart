/// Guardas escritas en la propia base: lo que la aplicación **no puede**
/// hacer, ni siquiera por error.
///
/// ## Por qué estos triggers y no más
///
/// Un trigger que *deriva* datos —mantener `stock_actual`, recalcular un
/// total— es mala idea en este proyecto: competiría con el repositorio que ya
/// hace ese trabajo, vive en SQL que `flutter analyze` no revisa, y convierte
/// cualquier «¿quién cambió esto?» en una cacería. Las derivaciones se quedan
/// en un solo punto del código, donde se revisan en el diff.
///
/// Un trigger que *prohíbe* es otra cosa. `RAISE(ABORT)` sobre una operación
/// que nunca debe ocurrir es una garantía que ningún bug futuro salta: no
/// duplica lógica, la clausura. Eso es lo único que hay aquí.
///
/// Se aplican en `onCreate`. Mientras `schemaVersion` siga en 1 y la base se
/// recree en desarrollo, con eso basta; el día que haya migraciones, cada paso
/// tendrá que volver a crearlas.
library;

/// Las sentencias, en orden de aplicación.
///
/// Cada una explica en su comentario qué invariante protege y por qué no
/// alcanza con hacerlo en Dart.
const List<String> guardasSql = [
  // ── El libro mayor del inventario es de solo escritura ──────────────────
  //
  // Corregir el pasado del inventario es rehacerlo con un movimiento nuevo,
  // no editar el viejo. Sin esta guarda, un `UPDATE` mal escrito descuadraría
  // el stock sin dejar ni rastro de que ocurrió.
  //
  // El `WHEN` deja pasar un caso: que se pongan en NULL las referencias al
  // documento de origen. Eso lo hace SQLite sola por el `ON DELETE SET NULL`
  // cuando se borra una reserva, y no toca la sustancia del movimiento.
  '''
  CREATE TRIGGER IF NOT EXISTS guarda_movimientos_inmutables
  BEFORE UPDATE ON movimientos_inventario
  FOR EACH ROW
  WHEN OLD.producto_id IS NOT NEW.producto_id
    OR OLD.cantidad    IS NOT NEW.cantidad
    OR OLD.tipo        IS NOT NEW.tipo
    OR OLD.creado_en   IS NOT NEW.creado_en
  BEGIN
    SELECT RAISE(ABORT,
      'Un movimiento de inventario no se edita: registra uno nuevo que lo corrija.');
  END;
  ''',

  '''
  CREATE TRIGGER IF NOT EXISTS guarda_movimientos_sin_borrado
  BEFORE DELETE ON movimientos_inventario
  FOR EACH ROW
  BEGIN
    SELECT RAISE(ABORT,
      'Un movimiento de inventario no se borra: registra la devolución.');
  END;
  ''',

  // ── Una factura no se borra ─────────────────────────────────────────────
  //
  // Es un documento contable: se anula, y la anulación queda registrada. Si se
  // pudiera borrar, el consecutivo de facturación quedaría con huecos y el
  // inventario, con salidas que ya no explica ningún documento.
  '''
  CREATE TRIGGER IF NOT EXISTS guarda_ventas_sin_borrado
  BEFORE DELETE ON ventas
  FOR EACH ROW
  BEGIN
    SELECT RAISE(ABORT,
      'Una factura no se borra: anúlala.');
  END;
  ''',

  // ── Una factura anulada está cerrada ────────────────────────────────────
  //
  // Se permite llegar a `ANULADA`; salir de ahí o retocar importes, no.
  '''
  CREATE TRIGGER IF NOT EXISTS guarda_ventas_anuladas_inmutables
  BEFORE UPDATE ON ventas
  FOR EACH ROW
  WHEN OLD.estado_pago = 'ANULADA'
  BEGIN
    SELECT RAISE(ABORT,
      'Una factura anulada no se modifica.');
  END;
  ''',

  // ── Ni sus líneas ───────────────────────────────────────────────────────
  //
  // Tres triggers y no uno porque SQLite no admite `FOR EACH ROW` sobre
  // varias operaciones a la vez. El de borrado mira `OLD`; los otros dos,
  // `NEW`.
  '''
  CREATE TRIGGER IF NOT EXISTS guarda_detalles_anulados_sin_alta
  BEFORE INSERT ON venta_detalles
  FOR EACH ROW
  WHEN (SELECT estado_pago FROM ventas WHERE id = NEW.venta_id) = 'ANULADA'
  BEGIN
    SELECT RAISE(ABORT,
      'No se le agregan líneas a una factura anulada.');
  END;
  ''',

  '''
  CREATE TRIGGER IF NOT EXISTS guarda_detalles_anulados_sin_edicion
  BEFORE UPDATE ON venta_detalles
  FOR EACH ROW
  WHEN (SELECT estado_pago FROM ventas WHERE id = OLD.venta_id) = 'ANULADA'
  BEGIN
    SELECT RAISE(ABORT,
      'No se editan las líneas de una factura anulada.');
  END;
  ''',

  '''
  CREATE TRIGGER IF NOT EXISTS guarda_detalles_anulados_sin_borrado
  BEFORE DELETE ON venta_detalles
  FOR EACH ROW
  WHEN (SELECT estado_pago FROM ventas WHERE id = OLD.venta_id) = 'ANULADA'
  BEGIN
    SELECT RAISE(ABORT,
      'No se borran las líneas de una factura anulada.');
  END;
  ''',

  // ── Una orden cerrada ya no recibe trabajo ──────────────────────────────
  //
  // Entregada la moto o anulada la orden, agregarle un repuesto descontaría
  // stock por un trabajo que nadie va a cobrar.
  '''
  CREATE TRIGGER IF NOT EXISTS guarda_repuestos_orden_cerrada
  BEFORE INSERT ON ordenes_repuestos
  FOR EACH ROW
  WHEN (SELECT estado FROM ordenes_servicio WHERE id = NEW.orden_id)
       IN ('ENTREGADA', 'ANULADA')
  BEGIN
    SELECT RAISE(ABORT,
      'La orden ya está cerrada: no admite más repuestos.');
  END;
  ''',

  '''
  CREATE TRIGGER IF NOT EXISTS guarda_tareas_orden_cerrada
  BEFORE INSERT ON ordenes_tareas
  FOR EACH ROW
  WHEN (SELECT estado FROM ordenes_servicio WHERE id = NEW.orden_id)
       IN ('ENTREGADA', 'ANULADA')
  BEGIN
    SELECT RAISE(ABORT,
      'La orden ya está cerrada: no admite más tareas.');
  END;
  ''',

  // ── Una devolución no devuelve más de lo que se vendió ──────────────────
  //
  // La invariante es un agregado sobre las otras filas de la tabla, así que
  // no cabe en un `CHECK`: hay que sumar lo ya devuelto de esa línea y
  // compararlo con lo que decía la factura. El repositorio lo valida antes
  // para poder dar un mensaje; esto es la red, y es lo que impide que dos
  // devoluciones seguidas de la misma línea se pasen entre las dos.
  //
  // El margen de 0.0001 es por la coma flotante de `cantidad`: devolver 0.3 y
  // 0.7 de una línea de 1.0 no puede fallar por el último bit.
  '''
  CREATE TRIGGER IF NOT EXISTS guarda_devolucion_no_excede_vendido
  BEFORE INSERT ON devolucion_detalles
  FOR EACH ROW
  WHEN NEW.cantidad
       + COALESCE((SELECT SUM(d.cantidad) FROM devolucion_detalles d
                   WHERE d.venta_detalle_id = NEW.venta_detalle_id), 0)
       > (SELECT vd.cantidad FROM venta_detalles vd
          WHERE vd.id = NEW.venta_detalle_id) + 0.0001
  BEGIN
    SELECT RAISE(ABORT,
      'No se puede devolver más de lo que se vendió en esa línea.');
  END;
  ''',

  // ── Una venta anulada ya no admite devoluciones ─────────────────────────
  //
  // Anular ya devolvió lo que quedaba por devolver. Aceptar una devolución
  // encima sería reponer dos veces el mismo stock.
  '''
  CREATE TRIGGER IF NOT EXISTS guarda_devolucion_venta_anulada
  BEFORE INSERT ON devoluciones
  FOR EACH ROW
  WHEN (SELECT estado_pago FROM ventas WHERE id = NEW.venta_id) = 'ANULADA'
  BEGIN
    SELECT RAISE(ABORT,
      'La venta está anulada: ya se devolvió todo lo que quedaba.');
  END;
  ''',

  // ── Una devolución tampoco se corrige ───────────────────────────────────
  //
  // Mismo argumento que el libro mayor: movió stock y movió plata, y ya dejó
  // su renglón en `movimientos_inventario`. Editarla o borrarla dejaría ese
  // movimiento explicando un documento que dice otra cosa. Si se recibió mal,
  // el camino es anular la venta entera.
  '''
  CREATE TRIGGER IF NOT EXISTS guarda_devoluciones_inmutables
  BEFORE UPDATE ON devoluciones
  FOR EACH ROW
  WHEN OLD.venta_id IS NOT NEW.venta_id
    OR OLD.total    IS NOT NEW.total
    OR OLD.numero   IS NOT NEW.numero
  BEGIN
    SELECT RAISE(ABORT,
      'Una devolución no se edita: es un documento que ya movió stock.');
  END;
  ''',

  '''
  CREATE TRIGGER IF NOT EXISTS guarda_devoluciones_sin_borrado
  BEFORE DELETE ON devoluciones
  FOR EACH ROW
  BEGIN
    SELECT RAISE(ABORT,
      'Una devolución no se borra: anula la venta si hay que deshacerla.');
  END;
  ''',

  // ── La bitácora es de solo escritura ────────────────────────────────────
  //
  // Mismo argumento que el libro mayor del inventario, y más fuerte: una
  // bitácora que se puede editar o borrar no prueba nada. Quien quisiera tapar
  // lo que hizo empezaría por su propio renglón, así que la única defensa que
  // vale es que la base no lo permita a nadie.
  '''
  CREATE TRIGGER IF NOT EXISTS guarda_bitacora_inmutable
  BEFORE UPDATE ON bitacora
  FOR EACH ROW
  BEGIN
    SELECT RAISE(ABORT,
      'La bitácora no se edita: es el registro de lo que ya pasó.');
  END;
  ''',

  '''
  CREATE TRIGGER IF NOT EXISTS guarda_bitacora_sin_borrado
  BEFORE DELETE ON bitacora
  FOR EACH ROW
  BEGIN
    SELECT RAISE(ABORT,
      'La bitácora no se borra.');
  END;
  ''',
];
