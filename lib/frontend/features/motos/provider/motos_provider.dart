import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/motos/modelo/moto.dart';
import '../../../../backend/features/motos/repositorio/repositorio_moto_impl.dart';
import '../../../../backend/features/motos/repositorio/repositorio_motos.dart';
import '../../../../backend/share/database/app_db_provider.dart';

final repositorioMotosProvider = Provider<RepositorioMotos>(
  name: 'repositorioMotosProvider',
  (ref) => RepositorioMotosImpl(ref.watch(appDatabaseProvider)),
);

class MotosState {
  final List<Moto> motos;
  final String textoBusqueda;

  const MotosState({required this.motos, this.textoBusqueda = ''});

  List<Moto> get filtrados {
    if (textoBusqueda.isEmpty) return motos;
    final t = textoBusqueda.toLowerCase();
    return motos.where((m) {
      return m.marca.toLowerCase().contains(t) ||
          m.modelo.toLowerCase().contains(t) ||
          (m.placa?.toLowerCase().contains(t) ?? false) ||
          (m.color?.toLowerCase().contains(t) ?? false) ||
          (m.vin?.toLowerCase().contains(t) ?? false) ||
          (m.nombreCliente?.toLowerCase().contains(t) ?? false);
    }).toList(growable: false);
  }

  MotosState copyWith({List<Moto>? motos, String? textoBusqueda}) =>
      MotosState(
        motos: motos ?? this.motos,
        textoBusqueda: textoBusqueda ?? this.textoBusqueda,
      );
}

class MotosNotifier extends AsyncNotifier<MotosState> {
  @override
  Future<MotosState> build() async {
    final repo = ref.watch(repositorioMotosProvider);
    final sub = repo.observarTodos().listen((lista) {
      final prev = state.value;
      state = AsyncData(MotosState(
        motos: lista,
        textoBusqueda: prev?.textoBusqueda ?? '',
      ));
    });
    ref.onDispose(sub.cancel);
    final inicial = await repo.obtenerTodos();
    return MotosState(motos: inicial);
  }

  void buscar(String texto) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(s.copyWith(textoBusqueda: texto));
  }

  Future<String?> crear(Moto moto) async {
    try {
      await ref.read(repositorioMotosProvider).crear(moto);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> actualizar(Moto moto) async {
    try {
      await ref.read(repositorioMotosProvider).actualizar(moto);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> eliminar(int id) async {
    try {
      await ref.read(repositorioMotosProvider).eliminar(id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

final motosProvider = AsyncNotifierProvider<MotosNotifier, MotosState>(
  MotosNotifier.new,
  name: 'motosProvider',
);

final motosPorClienteProvider = Provider.family<List<Moto>, int>(
  name: 'motosPorClienteProvider',
  (ref, clienteId) {
    return ref.watch(motosProvider).value?.motos
            .where((m) => m.clienteId == clienteId && m.activo)
            .toList(growable: false) ??
        const [];
  },
);
