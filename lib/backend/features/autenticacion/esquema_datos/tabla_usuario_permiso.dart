import 'package:drift/drift.dart';

import '../../../share/dominio/permiso.dart';
import 'tabla_usuario.dart';

/// Qué puede hacer cada cuenta. **Un permiso concedido es una fila.**
///
/// Estar en la tabla es tenerlo; no estar es no tenerlo. No hay columna
/// `permitido`: un booleano obligaría a distinguir «no lo tiene» de «nunca se
/// decidió», y para esto son lo mismo.
///
/// Los permisos son **por cuenta, no por rol**. El rol solo decide con cuáles
/// nace (`RolUsuario.permisosPorDefecto`); desde ahí cada cuenta va por su
/// lado, que es lo que hace falta cuando hay dos cajeros de confianza
/// distinta. Un administrador los tiene todos y su fila no se consulta.
///
/// `cascade`: los permisos no existen sin su cuenta. Es la excepción de
/// `REGLAS_BD.md` §3.2 que sí corresponde —no son un documento contable, son
/// un detalle de la cuenta—.
@TableIndex(name: 'idx_usuario_permisos_usuario', columns: {#usuarioId})
class TablaUsuarioPermiso extends Table {
  @override
  String get tableName => 'usuario_permisos';

  IntColumn get id => integer().autoIncrement()();

  IntColumn get usuarioId => integer()
      .references(TablaUsuario, #id, onDelete: KeyAction.cascade)();

  /// Uno de [Permiso].
  TextColumn get permiso => text()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {usuarioId, permiso},
      ];

  @override
  List<String> get customConstraints => [
        'CHECK (permiso IN (${Permiso.listaSql}))',
      ];
}
