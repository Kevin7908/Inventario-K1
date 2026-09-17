import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/unidades_medida/modelo/unidad_medida.dart';
import '../../../../backend/features/unidades_medida/repositorio/repositorio_unidades_medida.dart';
import '../../../../backend/features/unidades_medida/repositorio/repositorio_unidades_medida_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../../../core/resultado.dart';
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

  /// El repositorio valida, decide el motivo y redacta el texto (`REGLAS_BD.md`
  /// §8). Antes esas comprobaciones vivían aquí y devolvían un `String?`: el
  /// «ya existe» del nombre y el de la abreviatura llegaban indistinguibles a
  /// la vista, que solo podía volcarlos en un aviso genérico.
  Future<Resultado> crear({
    required String nombre,
    required String abreviatura,
    String tipo = 'unidad',
    String? descripcion,
  }) async {
    final ahora = DateTime.now();
    final resultado = await ref.read(repositorioUnidadesMedidaProvider).crear(
          UnidadMedida(
            nombre: nombre,
            abreviatura: abreviatura,
            tipo: tipo,
            descripcion: descripcion,
            creadoEn: ahora,
            actualizadoEn: ahora,
          ),
        );
    if (resultado.exitoso) await _recargar();
    return resultado;
  }

  Future<Resultado> actualizar({
    required int id,
    required String nombre,
    required String abreviatura,
    String? tipo,
    String? descripcion,
  }) async {
    final actual = state.value?.unidades.where((u) => u.id == id).firstOrNull;
    if (actual == null) {
      return const Fallo(
        MotivoFallo.validacion,
        'La unidad ya no está en la lista.',
      );
    }
    final resultado =
        await ref.read(repositorioUnidadesMedidaProvider).actualizar(
              actual.copyWith(
                nombre: nombre,
                abreviatura: abreviatura,
                tipo: tipo,
                descripcion: descripcion,
                actualizadoEn: DateTime.now(),
              ),
            );
    if (resultado.exitoso) await _recargar();
    return resultado;
  }

  Future<Resultado> eliminar(int id) async {
    final resultado =
        await ref.read(repositorioUnidadesMedidaProvider).eliminar(id);
    if (resultado.exitoso) await _recargar();
    return resultado;
  }
}

final unidadesMedidaProvider =
    AsyncNotifierProvider<UnidadesMedidaNotifier, UnidadesMedidaState>(
  UnidadesMedidaNotifier.new,
  name: 'unidadesMedidaProvider',
);
