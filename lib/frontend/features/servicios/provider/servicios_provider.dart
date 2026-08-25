import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../backend/features/servicios/modelo/servicio.dart';
import '../../../../backend/features/servicios/repositorio/repositorio_servicios.dart';
import '../../../../backend/features/servicios/repositorio/repositorio_servicios_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../autenticacion/provider/auth_providers.dart';

final repositorioServiciosProvider = Provider<RepositorioServicios>(
  (ref) => RepositorioServiciosImpl(
    ref.watch(appDatabaseProvider),
    // Quién firma lo que este repositorio escriba. Es una dependencia
    // del constructor, no un registro global (`CLAUDE.md` §3).
    ref.watch(sesionActualProvider),
  ),
  name: 'repositorioServiciosProvider',
);

//  Notifier 
class ServiciosNotifier extends AsyncNotifier<List<Servicio>> {
  RepositorioServicios get _repo => ref.read(repositorioServiciosProvider);

  // build() suscribe el Notifier al Stream de Drift.
  // Riverpod cancela la suscripcion automaticamente al destruir el provider.
  @override
  Future<List<Servicio>> build() async {
    final repo = ref.watch(repositorioServiciosProvider);

    ref.onDispose(
      repo.observarTodos().listen((lista) => state = AsyncData(lista)).cancel,
    );

    return repo.obtenerTodos();
  }

  Future<String?> agregar({
    required String nombre,
    String? descripcion,
    int precioSugerido = 0,
    bool activo = true,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _repo.agregar(
        nombre: nombre,
        descripcion: descripcion,
        precioSugerido: precioSugerido,
        activo: activo,
      ),
    );
    if (result is AsyncError) {
      state = await AsyncValue.guard(_repo.obtenerTodos);
      return _mensajeDeError(result.error);
    }
    return null;
  }

  Future<String?> actualizar({
    required int id,
    required String nombre,
    String? descripcion,
    int precioSugerido = 0,
    required bool activo,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _repo.actualizar(
        id: id,
        nombre: nombre,
        descripcion: descripcion,
        precioSugerido: precioSugerido,
        activo: activo,
      ),
    );
    if (result is AsyncError) {
      state = await AsyncValue.guard(_repo.obtenerTodos);
      return _mensajeDeError(result.error);
    }
    return null;
  }

  Future<String?> eliminar(int id) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => _repo.eliminar(id));
    if (result is AsyncError) {
      state = await AsyncValue.guard(_repo.obtenerTodos);
      return _mensajeDeError(result.error);
    }
    return null;
  }

  Future<void> alternarActivo(int id, {required bool activo}) async {
    // Operacion local silenciosa 
    try {
      await _repo.alternarActivo(id, activo: activo);
    } catch (e) {
      // El stream reactivo ya restaura el estado; no es necesario hacer nada mas
    }
  }

  // Helper 
  String _mensajeDeError(Object? error) {
    if (error == null) return 'Error desconocido.';
    final msg = error.toString();
    if (msg.contains('UNIQUE')) {
      return 'Ya existe un servicio con ese nombre.';
    }
    return msg;
  }
}

final serviciosProvider =
    AsyncNotifierProvider<ServiciosNotifier, List<Servicio>>(
  ServiciosNotifier.new,
  name: 'serviciosProvider',
);

//  Busqueda 
final busquedaServiciosProvider = StateProvider<String>(
  (ref) => '',
  name: 'busquedaServiciosProvider',
);

//Filtro activos/todos
final soloActivosServiciosProvider = StateProvider<bool>(
  (ref) => true,
  name: 'soloActivosServiciosProvider',
);

// Lista filtrada
final serviciosFiltradosProvider =
    Provider<AsyncValue<List<Servicio>>>(
  (ref) {
    final asyncLista = ref.watch(serviciosProvider);
    final query =
        ref.watch(busquedaServiciosProvider).trim().toLowerCase();
    final soloActivos = ref.watch(soloActivosServiciosProvider);

    return asyncLista.whenData((lista) {
      var resultado = lista;

      if (soloActivos) {
        resultado = resultado.where((s) => s.activo).toList(growable: false);
      }

      if (query.isEmpty) return resultado;

      return resultado.where((s) {
        return s.nombre.toLowerCase().contains(query) ||
            (s.descripcion?.toLowerCase().contains(query) ?? false);
      }).toList(growable: false);
    });
  },
  name: 'serviciosFiltradosProvider',
);