import 'package:drift/drift.dart';

import '../../../share/dominio/rol_usuario.dart';
import '../../persona/esquema_datos/tabla_persona.dart';

/// La cuenta de acceso de una persona.
///
/// El nombre y el correo no están aquí: vienen de `personas`. Esta tabla solo
/// guarda lo que hace falta para entrar a la app.
///
/// El rol es un `TextColumn` con `CHECK` y no el viejo `es_admin` booleano:
/// ver [RolUsuario] para el porqué.
class TablaUsuario extends Table {
  @override
  String get tableName => 'usuarios';

  IntColumn get id => integer().autoIncrement()();

  /// `restrict`: una cuenta borrada no puede llevarse a la persona, que puede
  /// ser además técnico o cliente.
  IntColumn get personaId => integer()
      .unique()
      .references(TablaPersona, #id, onDelete: KeyAction.restrict)();

  /// Con lo que se inicia sesión. Se guarda normalizado en minúsculas.
  ///
  /// No es lo único con lo que se entra: el correo de `personas` también
  /// sirve. Por eso la búsqueda del login mira las dos columnas.
  TextColumn get usuario => text().withLength(min: 3, max: 50).unique()();

  TextColumn get passwordHash => text()();

  /// Uno de [RolUsuario]. El `CHECK` sale del propio enum: agregar un rol no
  /// obliga a acordarse de esta tabla. El literal del `withDefault` sí tiene
  /// que ser constante, porque lo lee el generador de Drift.
  TextColumn get rol => text().withDefault(const Constant('CAJERO'))();

  BoolColumn get estaActivo => boolean().withDefault(const Constant(true))();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();

  /// Cambiar la contraseña, el rol o el estado de una cuenta es justo lo que
  /// alguien va a querer auditar; sin esta columna no queda ni la fecha.
  DateTimeColumn get actualizadoEn =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        'CHECK (rol IN (${RolUsuario.listaSql}))',
        'CHECK (length(trim(usuario)) >= 3)',
        'CHECK (length(password_hash) > 0)',
      ];
}
