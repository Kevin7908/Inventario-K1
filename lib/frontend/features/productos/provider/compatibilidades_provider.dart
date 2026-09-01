import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/productos/modelo/compatibilidad.dart';
import '../../../../backend/features/productos/repositorio/repositorio_compatibilidades.dart';
import '../../../../backend/features/productos/repositorio/repositorio_compatibilidades_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../autenticacion/provider/auth_providers.dart';

final repositorioCompatibilidadesProvider =
    Provider<RepositorioCompatibilidades>(
  name: 'repositorioCompatibilidadesProvider',
  (ref) => RepositorioCompatibilidadesImpl(
    ref.watch(appDatabaseProvider),
    // Quién firma lo que este repositorio escriba. Es una dependencia del
    // constructor, no un registro global (`CLAUDE.md` §3).
    ref.watch(sesionActualProvider),
  ),
);

/// A qué motos le sirve un repuesto.
///
/// Es `family` y no un provider por producto abierto porque la ficha se abre
/// de una en una: Riverpod descarta la suscripción al cerrarla.
final compatibilidadesProvider =
    StreamProvider.family<List<Compatibilidad>, int>(
  name: 'compatibilidadesProvider',
  (ref, productoId) => ref
      .watch(repositorioCompatibilidadesProvider)
      .observarDeProducto(productoId),
);
