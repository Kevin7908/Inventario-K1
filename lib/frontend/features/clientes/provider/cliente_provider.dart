import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../backend/features/clientes/repositorio/repositorio_cliente.dart';
import '../../../../backend/features/clientes/repositorio/repositorio_cliente_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';

final repositorioClientesProvider = Provider<RepositorioClientes>(
  name: 'repositorioClientesProvider',
  (ref) => RepositorioClientesImpl(ref.watch(appDatabaseProvider)),
);

class ClientesState {
  final List<Cliente> clientes;
  final String textoBusqueda;

  const ClientesState({required this.clientes, this.textoBusqueda = ''});

  List<Cliente> get filtrados {
    if (textoBusqueda.isEmpty) return clientes;
    final t = textoBusqueda.toLowerCase();
    return clientes.where((c) {
      return c.nombreCompleto.toLowerCase().contains(t) ||
          (c.cedula?.toLowerCase().contains(t) ?? false) ||
          (c.telefono?.toLowerCase().contains(t) ?? false) ||
          (c.email?.toLowerCase().contains(t) ?? false) ||
          (c.ciudad?.toLowerCase().contains(t) ?? false);
    }).toList(growable: false);
  }

  ClientesState copyWith({List<Cliente>? clientes, String? textoBusqueda}) =>
      ClientesState(
        clientes: clientes ?? this.clientes,
        textoBusqueda: textoBusqueda ?? this.textoBusqueda,
      );
}

class ClientesNotifier extends AsyncNotifier<ClientesState> {
  @override
  Future<ClientesState> build() async {
    final repo = ref.watch(repositorioClientesProvider);
    final sub = repo.observarTodos().listen((lista) {
      final prev = state.value;
      state = AsyncData(ClientesState(
        clientes: lista,
        textoBusqueda: prev?.textoBusqueda ?? '',
      ));
    });
    ref.onDispose(sub.cancel);
    final inicial = await repo.obtenerTodos();
    return ClientesState(clientes: inicial);
  }

  void buscar(String texto) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(s.copyWith(textoBusqueda: texto));
  }

  Future<String?> crear(Cliente cliente) async {
    try {
      await ref.read(repositorioClientesProvider).crear(cliente);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> actualizar(Cliente cliente) async {
    try {
      await ref.read(repositorioClientesProvider).actualizar(cliente);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> eliminar(int id) async {
    try {
      await ref.read(repositorioClientesProvider).eliminar(id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

final clientesProvider =
    AsyncNotifierProvider<ClientesNotifier, ClientesState>(
  ClientesNotifier.new,
  name: 'clientesProvider',
);
