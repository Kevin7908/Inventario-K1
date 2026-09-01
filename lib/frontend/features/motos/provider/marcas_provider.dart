import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/motos/modelo/marca_moto.dart';
import '../../../../backend/features/motos/repositorio/repositorio_marcas_moto.dart';
import '../../../../backend/features/motos/repositorio/repositorio_marcas_moto_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../autenticacion/provider/auth_providers.dart';

final repositorioMarcasMotoProvider = Provider<RepositorioMarcasMoto>(
  name: 'repositorioMarcasMotoProvider',
  (ref) => RepositorioMarcasMotoImpl(
    ref.watch(appDatabaseProvider),
    // Quién firma lo que este repositorio escriba. Es una dependencia del
    // constructor, no un registro global (`CLAUDE.md` §3).
    ref.watch(sesionActualProvider),
  ),
);

/// Todas las marcas, activas y dadas de baja, con su conteo de modelos.
///
/// Lo observa la pestaña de Configuración, que necesita ver también las
/// inactivas para poder reactivarlas.
final marcasMotoProvider = StreamProvider<List<MarcaMoto>>(
  name: 'marcasMotoProvider',
  (ref) => ref.watch(repositorioMarcasMotoProvider).observarMarcas(),
);

/// Solo las marcas vigentes. Es lo que ofrece un selector: dar de baja una
/// marca es dejar de ofrecerla, no esconder las motos que ya la usan.
final marcasActivasProvider = StreamProvider<List<MarcaMoto>>(
  name: 'marcasActivasProvider',
  (ref) =>
      ref.watch(repositorioMarcasMotoProvider).observarMarcas(soloActivas: true),
);

/// Los modelos de una marca. `null` trae los de todas, que es lo que pide el
/// selector de compatibilidades.
final modelosMotoProvider =
    StreamProvider.family<List<ModeloMoto>, int?>(
  name: 'modelosMotoProvider',
  (ref, marcaId) => ref
      .watch(repositorioMarcasMotoProvider)
      .observarModelos(marcaId: marcaId),
);

/// Los modelos vigentes de todo el catálogo, para elegir compatibilidades.
final modelosActivosProvider = StreamProvider<List<ModeloMoto>>(
  name: 'modelosActivosProvider',
  (ref) => ref
      .watch(repositorioMarcasMotoProvider)
      .observarModelos(soloActivos: true),
);
