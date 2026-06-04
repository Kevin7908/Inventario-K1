import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../backend/features/tecnicos/modelo/tecnico.dart';
import '../../../../backend/features/tecnicos/repositorio/repositorio_tecnico.dart';
import '../../../../backend/features/tecnicos/repositorio/repositorio_tecnico_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';

final repositorioTecnicoProvider = Provider<RepositorioTecnico>(
  (ref) => RepositorioTecnicoDrift(ref.watch(appDatabaseProvider)),
  name: 'repositorioTecnicoProvider',
);

class TecnicosNotifier extends AsyncNotifier<List<Tecnico>> {
  late final RepositorioTecnico _repo;

  @override
  Future<List<Tecnico>> build() async {
    _repo = ref.watch(repositorioTecnicoProvider);

    // Suscripción al Stream de drift, el provider se actualiza
    // automáticamente cada vez que la tabla cambia.
    final stream = _repo.observarTodos();
    final completer = Completer<List<Tecnico>>();

    ref.onDispose(
      stream.listen(
        (lista) {
          if (!completer.isCompleted) completer.complete(lista);
          state = AsyncData(lista);
        },
        onError: (e, st) {
          if (!completer.isCompleted) completer.completeError(e, st);
          state = AsyncError(e, st);
        },
      ).cancel,
    );

    return completer.future;
  }

  Future<String?> agregar({
    required String nombres,
    String? cedula,
    String? apellidos,
    String? telefono,
    String? email,
    int? especializacionId,
    double? salarioBase,
    required bool activo,
  }) async {
    // Validación de cédula duplicada
    if (cedula != null && cedula.isNotEmpty) {
      final existe = await _repo.existeCedula(cedula);
      if (existe) return 'Ya existe un técnico con la cédula $cedula';
    }

    final result = await AsyncValue.guard(
      () => _repo.insertar(
        nombres: nombres,
        cedula: cedula,
        apellidos: apellidos,
        telefono: telefono,
        email: email,
        especializacionId: especializacionId,
        salarioBase: salarioBase,
        activo: activo,
      ),
    );

    return result.whenOrNull(error: (e, _) => e.toString());
  }

  Future<String?> editar({
    required int id,
    required String nombres,
    String? cedula,
    String? apellidos,
    String? telefono,
    String? email,
    int? especializacionId,
    double? salarioBase,
    required bool activo,
  }) async {
    if (cedula != null && cedula.isNotEmpty) {
      final existe = await _repo.existeCedula(cedula, excluirId: id);
      if (existe) return 'Ya existe otro técnico con la cédula $cedula';
    }

    final result = await AsyncValue.guard(
      () => _repo.actualizar(
        id: id,
        nombres: nombres,
        cedula: cedula,
        apellidos: apellidos,
        telefono: telefono,
        email: email,
        especializacionId: especializacionId,
        salarioBase: salarioBase,
        activo: activo,
      ),
    );

    return result.whenOrNull(error: (e, _) => e.toString());
  }

  Future<String?> eliminar(int id) async {
    final result = await AsyncValue.guard(() => _repo.eliminar(id));
    return result.whenOrNull(error: (e, _) => e.toString());
  }
}

final tecnicosProvider =
    AsyncNotifierProvider<TecnicosNotifier, List<Tecnico>>(
  TecnicosNotifier.new,
  name: 'tecnicosProvider',
);

// Texto de busqueda ingresado por el usuario.
final busquedaTecnicoProvider = StateProvider<String>(
  (ref) => '',
  name: 'busquedaTecnicoProvider',
);

// Lista filtrada derivada: no requiere nueva consulta a la BD.
final tecnicosFiltradosProvider = Provider<AsyncValue<List<Tecnico>>>(
  (ref) {
    final asyncTecnicos = ref.watch(tecnicosProvider);
    final busqueda = ref.watch(busquedaTecnicoProvider).toLowerCase().trim();

    return asyncTecnicos.whenData((lista) {
      if (busqueda.isEmpty) return lista;
      return lista.where((t) {
        return t.nombreCompleto.toLowerCase().contains(busqueda) ||
            (t.cedula?.toLowerCase().contains(busqueda) ?? false) ||
            (t.especializacionId?.toString().contains(busqueda) ?? false);
      }).toList();
    });
  },
  name: 'tecnicosFiltradosProvider',
);