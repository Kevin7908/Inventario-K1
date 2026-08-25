// frontend/features/especializaciones/providers/especializaciones_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../backend/features/especializacion/modelo/especializacion.dart';
import '../../../../backend/features/especializacion/repositorio/repositorio_especializacion.dart';
import '../../../../backend/features/especializacion/repositorio/repositorio_especializacion_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
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

  /// Retorna null si tuvo éxito, o el mensaje de error si falló.
  Future<String?> agregar({
    required String nombre,
    String? descripcion,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _repo.agregar(nombre: nombre, descripcion: descripcion),
    );
    if (result is AsyncError) {
      // Restaura lista actual antes de retornar error
      state = await AsyncValue.guard(_repo.obtenerTodas);
      return _mensajeDeError(result.error);
    }
    return null; // éxito
  }

  // Actualizar 
  Future<String?> actualizar({
    required int id,
    required String nombre,
    String? descripcion,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _repo.actualizar(id: id, nombre: nombre, descripcion: descripcion),
    );
    if (result is AsyncError) {
      state = await AsyncValue.guard(_repo.obtenerTodas);
      return _mensajeDeError(result.error);
    }
    return null;
  }

  // Eliminar
  Future<String?> eliminar(int id) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => _repo.eliminar(id));
    if (result is AsyncError) {
      state = await AsyncValue.guard(_repo.obtenerTodas);
      return _mensajeDeError(result.error);
    }
    return null;
  }

  //  Helper 
  String _mensajeDeError(Object? error) {
    if (error == null) return 'Error desconocido';
    final msg = error.toString();
    if (msg.contains('UNIQUE')) {
      return 'Ya existe una especialización con ese nombre.';
    }
    return msg;
  }
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