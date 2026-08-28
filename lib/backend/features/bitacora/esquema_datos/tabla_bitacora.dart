import 'package:drift/drift.dart';

import '../../autenticacion/esquema_datos/tabla_usuario.dart';
import '../modelo/entrada_bitacora.dart';

/// Quién hizo qué, y cuándo.
///
/// Es el complemento de las columnas `usuario_id` que llevan los documentos:
/// aquéllas dicen **quién creó** una venta o una orden y viven dentro del
/// documento; ésta es la única que puede responder **quién editó o borró** algo
/// —cuando la fila se va, su columna se va con ella—.
///
/// **De solo escritura**, como `movimientos_inventario`: una bitácora que se
/// puede corregir no sirve para nada. La guarda que lo impide vive en
/// `guardas_sql.dart`.
///
/// ### Por qué `entidad_id` no es una clave foránea
///
/// Sería polimórfica —apunta a productos, a clientes o a ventas según
/// `entidad`—, y la base no puede verificar eso. Pero además, las dos
/// políticas posibles rompen justo lo que esta tabla existe para conservar:
/// `restrict` impediría borrar el producto, y `cascade` se llevaría el renglón
/// que cuenta que alguien lo borró. Por eso es un entero suelto, y por eso
/// [descripcion] guarda el nombre: es la parte legible que sobrevive al
/// borrado.
///
/// [descripcion] es un snapshot en el sentido de `REGLAS_BD.md` §1.2: se
/// guarda **además** del id, pertenece a un hecho cerrado y no se actualiza
/// nunca.
@TableIndex(name: 'idx_bitacora_usuario_fecha', columns: {#usuarioId, #creadoEn})
@TableIndex(name: 'idx_bitacora_entidad', columns: {#entidad, #entidadId})
@TableIndex(name: 'idx_bitacora_fecha', columns: {#creadoEn})
class TablaBitacora extends Table {
  @override
  String get tableName => 'bitacora';

  IntColumn get id => integer().autoIncrement()();

  /// `restrict`: una cuenta con historial no se borra. En la práctica ninguna
  /// se borra —se desactivan—, pero la base no tiene por qué confiar en eso.
  IntColumn get usuarioId => integer()
      .references(TablaUsuario, #id, onDelete: KeyAction.restrict)();

  /// Uno de [EntidadAuditada].
  TextColumn get entidad => text()();

  /// Id de la fila afectada. Sin FK, a propósito: ver el docstring de arriba.
  IntColumn get entidadId => integer().nullable()();

  /// Uno de [AccionAuditada].
  TextColumn get accion => text()();

  /// Cómo se llamaba lo afectado cuando pasó.
  TextColumn get descripcion => text()();

  /// Qué cambió. Opcional y en texto libre.
  TextColumn get detalle => text().nullable()();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        'CHECK (entidad IN (${EntidadAuditada.listaSql}))',
        'CHECK (accion IN (${AccionAuditada.listaSql}))',
        'CHECK (length(trim(descripcion)) > 0)',
      ];
}
