import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/persona/repositorio/repositorio_persona.dart';
import '../../../../backend/features/persona/repositorio/repositorio_persona_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';

/// Acceso a la tabla `personas`, compartido por los módulos que dan de alta a
/// alguien: clientes, técnicos y proveedores.
///
/// No tiene notifier ni estado propio a propósito: nadie lista personas. Se
/// consulta puntualmente para saber si un documento ya está registrado y, si
/// lo está, con qué roles.
final repositorioPersonaProvider = Provider<RepositorioPersona>(
  name: 'repositorioPersonaProvider',
  (ref) => RepositorioPersonaImpl(ref.watch(appDatabaseProvider)),
);
