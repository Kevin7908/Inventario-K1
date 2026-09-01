// frontend/features/especializaciones/providers/especializaciones_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../backend/features/especializacion/modelo/especializacion.dart';
import '../../../../backend/features/especializacion/repositorio/repositorio_especializacion.dart';
import '../../../../backend/features/especializacion/repositorio/repositorio_especializacion_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../../../core/resultado.dart';
import '../../autenticacion/provider/auth_providers.dart';

// Repositorio concreto. Cambiar la impl aquí no toca ninguna otra capa.
final repositorioEspecializacionProvider =
    Provider<RepositorioEspecializacion>(
  (ref) => RepositorioEspecializacionImpl(
    ref.watch(appDatabaseProvider),
    // Quién firma lo que este repositorio escriba. Es una dependencia
    // del constructor, no un registro global (`CLAUDE.md` §3).
    ref.watch(sesionActualProvider),
  ),
  name: 'repositorioEspecializacionProvider',
);

class EspecializacionesNotifier
    extends AsyncNotifier<List<Especializacion>> {
  RepositorioEspecializacion get _repo =>
      ref.read(repositorioEspecializacionProvider);

  // build() suscribe el Notifier al Stream de Drift.
  // Riverpod cancela la suscripción automáticamente al destruir el provider.
  @override
  Future<List<Especializacion>> build() async {
    final repo = ref.watch(repositorioEspecializacionProvider);

    // Suscribimos el stream; cada emisión actualiza el estado.
    ref.onDispose(
      repo.observarTodas().listen((lista) => state = AsyncData(lista)).cancel,
    );

    // Valor inicial: primer snapshot.
    return repo.obtenerTodas();
  }

  /// El repositorio ya valida, decide el motivo y redacta el texto: aquí no
  /// queda nada que traducir. Antes este notifier buscaba `UNIQUE` dentro del
  /// `toString()` de la excepción para adivinar que el nombre estaba repetido,
  /// que es justo lo que `Resultado` vino a evitar.
  ///
  /// Tampoco toca `state`: el stream de Drift que suscribe `build()` re-emite
  /// solo en cuanto la tabla cambia. El `AsyncLoading` + recarga manual que
  /// había aquí hacía el mismo trabajo dos veces y parpadeaba la lista.
  Future<Resultado> agregar({
    required String nombre,
    String? descripcion,
  }) =>
      _repo.agregar(nombre: nombre, descripcion: descripcion);

  Future<Resultado> actualizar({
    required int id,
    required String nombre,
    String? descripcion,
  }) =>
      _repo.actualizar(id: id, nombre: nombre, descripcion: descripcion);

  Future<Resultado> eliminar(int id) => _repo.eliminar(id);
}

final especializacionesProvider =
    AsyncNotifierProvider<EspecializacionesNotifier, List<Especializacion>>(
  EspecializacionesNotifier.new,
  name: 'especializacionesProvider',
);

// Búsqueda — StateProvider + Provider derivado
/// Texto de búsqueda. La vista lo escribe; el provider derivado lo lee.
final busquedaEspecializacionProvider = StateProvider<String>(
  (ref) => '',
  name: 'busquedaEspecializacionProvider',
);

// Lista filtrada — se recalcula reactivamente cuando cambia la lista o la búsqueda.
// Toda la lógica de filtrado vive aquí, fuera de la UI.
final especializacionesFiltradasProvider =
    Provider<AsyncValue<List<Especializacion>>>(
  (ref) {
    final asyncLista = ref.watch(especializacionesProvider);
    final query = ref.watch(busquedaEspecializacionProvider).trim().toLowerCase();

    return asyncLista.whenData((lista) {
      if (query.isEmpty) return lista;
      return lista.where((e) {
        return e.nombre.toLowerCase().contains(query) ||
            (e.descripcion?.toLowerCase().contains(query) ?? false);
      }).toList(growable: false);
    });
  },
  name: 'especializacionesFiltradasProvider',
);