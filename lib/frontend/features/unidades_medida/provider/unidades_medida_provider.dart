import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/unidades_medida/modelo/unidad_medida.dart';
import '../../../../backend/features/unidades_medida/repositorio/repositorio_unidades_medida.dart';
import '../../../../backend/features/unidades_medida/repositorio/repositorio_unidades_medida_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../autenticacion/provider/auth_providers.dart';

final repositorioUnidadesMedidaProvider = Provider<RepositorioUnidadesMedida>(
  name: 'repositorioUnidadesMedidaProvider',
  (ref) => RepositorioUnidadesMedidaImpl(
    ref.watch(appDatabaseProvider),
    // Quién firma lo que este repositorio escriba. Es una dependencia
    // del constructor, no un registro global (`CLAUDE.md` §3).
    ref.watch(sesionActualProvider),
  ),
);

class UnidadesMedidaState {
  final List<UnidadMedida> unidades;
  final String textoBusqueda;
  final String filtroTipo;

  const UnidadesMedidaState({
    required this.unidades,
    this.textoBusqueda = '',
    this.filtroTipo = 'todos',
  });

  List<UnidadMedida> get filtradas {
    var lista = unidades;
    if (filtroTipo != 'todos') {
      lista = lista.where((u) => u.tipo == filtroTipo).toList();
    }
    if (textoBusqueda.isNotEmpty) {
      final t = textoBusqueda.toLowerCase();
      lista = lista
          .where(
            (u) =>
                u.nombre.toLowerCase().contains(t) ||
                u.abreviatura.toLowerCase().contains(t),
          )
          .toList();
    }
    return lista;
  }

  UnidadesMedidaState copyWith({
    List<UnidadMedida>? unidades,
    String? textoBusqueda,
    String? filtroTipo,
  }) => UnidadesMedidaState(
    unidades: unidades ?? this.unidades,
    textoBusqueda: textoBusqueda ?? this.textoBusqueda,
    filtroTipo: filtroTipo ?? this.filtroTipo,
  );
}

class UnidadesMedidaNotifier extends AsyncNotifier<UnidadesMedidaState> {
  @override
  Future<UnidadesMedidaState> build() async {
    final unidades =
        await ref.watch(repositorioUnidadesMedidaProvider).obtenerTodas();
    return UnidadesMedidaState(unidades: unidades);
  }

  Future<void> _recargar() async {
    final prev = state.value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final unidades =
          await ref.read(repositorioUnidadesMedidaProvider).obtenerTodas();
      return UnidadesMedidaState(
        unidades: unidades,
        textoBusqueda: prev?.textoBusqueda ?? '',
        filtroTipo: prev?.filtroTipo ?? 'todos',
      );
    });
  }

  void buscar(String texto) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(s.copyWith(textoBusqueda: texto));
  }

  void filtrarPorTipo(String tipo) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(s.copyWith(filtroTipo: tipo));
  }

  Future<String?> crear({
    required String nombre,
    required String abreviatura,
    String tipo = 'unidad',
    String? descripcion,
  }) async {
    try {
      final repo = ref.read(repositorioUnidadesMedidaProvider);
      if (nombre.trim().isEmpty) return 'El nombre no puede estar vacío';
      if (abreviatura.trim().isEmpty) return 'La abreviatura no puede estar vacía';
      if (await repo.existeNombre(nombre.trim())) {
        return 'Ya existe una unidad con ese nombre';
      }
      if (await repo.existeAbreviatura(abreviatura.trim())) {
        return 'Ya existe una unidad con esa abreviatura';
      }
      await repo.crear(UnidadMedida(
        nombre: nombre.trim(),
        abreviatura: abreviatura.trim(),
        tipo: tipo,
        descripcion: descripcion?.trim(),
        creadoEn: DateTime.now(),
        actualizadoEn: DateTime.now(),
      ));
      await _recargar();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> actualizar({
    required int id,
    required String nombre,
    required String abreviatura,
    String? tipo,
    String? descripcion,
  }) async {
    try {
      final repo = ref.read(repositorioUnidadesMedidaProvider);
      if (await repo.existeNombre(nombre.trim(), excludirId: id)) {
        return 'Ya existe una unidad con ese nombre';
      }
      if (await repo.existeAbreviatura(abreviatura.trim(), excludirId: id)) {
        return 'Ya existe una unidad con esa abreviatura';
      }
      final actual =
          state.value!.unidades.firstWhere((u) => u.id == id);
      await repo.actualizar(actual.copyWith(
        nombre: nombre.trim(),
        abreviatura: abreviatura.trim(),
        tipo: tipo,
        descripcion: descripcion?.trim(),
        actualizadoEn: DateTime.now(),
      ));
      await _recargar();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> eliminar(int id) async {
    try {
      await ref.read(repositorioUnidadesMedidaProvider).eliminar(id);
      await _recargar();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

final unidadesMedidaProvider =
    AsyncNotifierProvider<UnidadesMedidaNotifier, UnidadesMedidaState>(
  UnidadesMedidaNotifier.new,
  name: 'unidadesMedidaProvider',
);
