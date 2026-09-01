import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../backend/features/servicios/modelo/servicio.dart';
import '../../../../backend/features/servicios/repositorio/repositorio_servicios.dart';
import '../../../../backend/features/servicios/repositorio/repositorio_servicios_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../../../core/resultado.dart';
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

  /// El repositorio ya valida, decide el motivo y redacta el texto: aquí no
  /// queda nada que traducir. Antes este notifier leía `UNIQUE` dentro del
  /// `toString()` de la excepción para adivinar que el nombre estaba repetido.
  Future<Resultado> agregar({
    required String nombre,
    String? descripcion,
    int precioSugerido = 0,
    bool activo = true,
  }) =>
      _repo.agregar(
        nombre: nombre,
        descripcion: descripcion,
        precioSugerido: precioSugerido,
        activo: activo,
      );

  Future<Resultado> actualizar({
    required int id,
    required String nombre,
    String? descripcion,
    int precioSugerido = 0,
    required bool activo,
  }) =>
      _repo.actualizar(
        id: id,
        nombre: nombre,
        descripcion: descripcion,
        precioSugerido: precioSugerido,
        activo: activo,
      );

  Future<Resultado> eliminar(int id) => _repo.eliminar(id);

  Future<Resultado> alternarActivo(int id, {required bool activo}) =>
      _repo.alternarActivo(id, activo: activo);
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