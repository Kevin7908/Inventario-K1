import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../backend/features/clientes/repositorio/repositorio_cliente.dart';
import '../../../../backend/features/clientes/repositorio/repositorio_cliente_impl.dart';
import '../../../../backend/features/motos/modelo/moto.dart';
import '../../../../backend/features/motos/repositorio/repositorio_motos.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../../../core/resultado.dart';
import '../../motos/provider/motos_provider.dart';
import 'validacion_cliente.dart';
import '../../autenticacion/provider/auth_providers.dart';

// Repositorio

final repositorioClientesProvider = Provider<RepositorioClientes>(
  name: 'repositorioClientesProvider',
  (ref) => RepositorioClientesImpl(
    ref.watch(appDatabaseProvider),
    // Quién firma lo que este repositorio escriba. Es una dependencia
    // del constructor, no un registro global (`CLAUDE.md` §3).
    ref.watch(sesionActualProvider),
  ),
);

// Estado

/// Estado del catálogo de clientes: **solo la página visible**.
///
/// El filtrado, el conteo y el recorte los hace SQLite. Quien necesite todos
/// los clientes —los selectores de facturas, órdenes y deudores— usa
/// [catalogoClientesProvider].
final class ClientesState {
  const ClientesState({
    this.items = const [],
    this.total = 0,
    this.pagina = 0,
    this.tamanoPagina = 12,
    this.busqueda = '',
  });

  /// Clientes de la página actual.
  final List<Cliente> items;

  /// Total de clientes que cumplen el filtro, en todas las páginas.
  final int total;

  /// Página actual, de base cero.
  final int pagina;
  final int tamanoPagina;

  final String busqueda;

  int get totalPaginas =>
      total <= 0 ? 1 : (total + tamanoPagina - 1) ~/ tamanoPagina;

  bool get hayFiltro => busqueda.isNotEmpty;

  /// Traduce los filtros de la interfaz a los que entiende el repositorio.
  FiltroClientes get filtro => FiltroClientes(busqueda: busqueda);

  ClientesState copyWith({
    List<Cliente>? items,
    int? total,
    int? pagina,
    int? tamanoPagina,
    String? busqueda,
  }) =>
      ClientesState(
        items:        items        ?? this.items,
        total:        total        ?? this.total,
        pagina:       pagina       ?? this.pagina,
        tamanoPagina: tamanoPagina ?? this.tamanoPagina,
        busqueda:     busqueda     ?? this.busqueda,
      );
}

// Notifier

class ClientesNotifier extends AsyncNotifier<ClientesState> {
  late final RepositorioClientes _repo;
  late final RepositorioMotos _motos;
  StreamSubscription<PaginaClientes>? _sub;

  @override
  Future<ClientesState> build() async {
    _repo = ref.watch(repositorioClientesProvider);
    _motos = ref.watch(repositorioMotosProvider);
    ref.onDispose(() => _sub?.cancel());

    const inicial = ClientesState();
    final primera = await _repo
        .observarPagina(
          filtro: inicial.filtro,
          pagina: inicial.pagina,
          tamano: inicial.tamanoPagina,
        )
        .first;

    _suscribir(inicial);
    return inicial.copyWith(items: primera.items, total: primera.total);
  }

  /// Reabre el stream con los filtros y la página vigentes.
  ///
  /// Cada cambio de filtro es una consulta nueva: por eso se cancela la
  /// suscripción anterior en vez de recortar en memoria.
  void _suscribir(ClientesState estado) {
    _sub?.cancel();
    _sub = _repo
        .observarPagina(
          filtro: estado.filtro,
          pagina: estado.pagina,
          tamano: estado.tamanoPagina,
        )
        .listen(
      (pagina) {
        final actual = state.value;
        if (actual == null) return;
        state = AsyncData(
          actual.copyWith(items: pagina.items, total: pagina.total),
        );
      },
      onError: (Object e, StackTrace st) => state = AsyncError(e, st),
    );
  }

  void _aplicar(ClientesState nuevo) {
    state = AsyncData(nuevo);
    _suscribir(nuevo);
  }

  // Filtros — todos vuelven a la primera página, porque el conjunto cambió.

  void buscar(String query) {
    final actual = state.value;
    if (actual == null) return;
    final limpio = query.trim();
    if (actual.busqueda == limpio) return;
    _aplicar(actual.copyWith(busqueda: limpio, pagina: 0));
  }

  void irAPagina(int pagina) {
    final actual = state.value;
    if (actual == null || pagina == actual.pagina) return;
    if (pagina < 0 || pagina >= actual.totalPaginas) return;
    _aplicar(actual.copyWith(pagina: pagina));
  }

  // Mutaciones

  /// Alta o edición del cliente **junto con sus motos**.
  ///
  /// Es un solo método y no un `crear`/`actualizar` separados porque el
  /// formulario guarda las dos cosas a la vez y el repositorio lo resuelve en
  /// una transacción: un cliente con `id == 0` se inserta, el resto se
  /// actualiza.
  Future<Resultado> guardar({
    required Cliente cliente,
    required List<Moto> motos,
  }) async {
    final invalido = await validarCliente(
      cliente: cliente,
      motos: motos,
      repoClientes: _repo,
      repoMotos: _motos,
    );
    if (invalido != null) return invalido;

    try {
      await _repo.guardarConMotos(cliente: cliente, motos: motos);
      return const Exito();
    } catch (e) {
      return Fallo(MotivoFallo.persistencia, 'No se pudo guardar el cliente: $e');
    }
  }

  Future<Resultado> eliminar(int id) async {
    try {
      await _repo.eliminar(id);
      return const Exito();
    } catch (e) {
      // La FK de `deudores` es RESTRICT: un cliente con deudas registradas no
      // se puede borrar, y el mensaje crudo de SQLite no se lo explica a nadie.
      return const Fallo(
        MotivoFallo.persistencia,
        'No se pudo eliminar el cliente. Puede tener órdenes, facturas o '
        'deudas asociadas.',
      );
    }
  }
}

// Providers públicos

final clientesProvider =
    AsyncNotifierProvider<ClientesNotifier, ClientesState>(
  ClientesNotifier.new,
  name: 'clientesProvider',
);

/// Catálogo completo de clientes, en vivo.
///
/// Para lo que necesita todos: los selectores de cliente de facturas, órdenes,
/// deudores y motos. La grilla de Clientes no lo usa —esa va paginada contra
/// la base de datos.
final catalogoClientesProvider = StreamProvider<List<Cliente>>(
  name: 'catalogoClientesProvider',
  (ref) => ref.watch(repositorioClientesProvider).observarTodos(),
);

/// Clientes de la página actual.
final clientesFiltradosProvider = Provider<List<Cliente>>(
  name: 'clientesFiltradosProvider',
  (ref) => ref.watch(clientesProvider).value?.items ?? const [],
);

/// Conteos del encabezado, resueltos con `COUNT` en SQL.
final clientesResumenProvider = StreamProvider<ResumenClientes>(
  name: 'clientesResumenProvider',
  (ref) => ref.watch(repositorioClientesProvider).observarResumen(),
);

/// Saldo pendiente de cada cliente que debe algo, indexado por id.
///
/// Los clientes al día no aparecen en el mapa. El `distinct` compara el
/// contenido: Drift re-emite ante cualquier cambio en `deudores`, y sin esto
/// la grilla se reconstruiría aunque ningún saldo hubiera cambiado.
final saldosClientesProvider = StreamProvider<Map<int, SaldoCliente>>(
  name: 'saldosClientesProvider',
  (ref) => ref
      .watch(repositorioClientesProvider)
      .observarSaldos()
      .distinct(_mismoMapa),
);

/// Cuántas motos tiene cada cliente y cuál mostrar primero.
final resumenMotosPorClienteProvider =
    StreamProvider<Map<int, ResumenMotosCliente>>(
  name: 'resumenMotosPorClienteProvider',
  (ref) => ref
      .watch(repositorioMotosProvider)
      .observarResumenPorCliente()
      .distinct(_mismoMapa),
);

/// Motos de un cliente concreto, en vivo. Lo usa la ficha del cliente.
final motosDeClienteProvider = StreamProvider.family<List<Moto>, int>(
  name: 'motosDeClienteProvider',
  (ref, clienteId) =>
      ref.watch(repositorioMotosProvider).observarPorCliente(clienteId),
);

bool _mismoMapa<T>(Map<int, T> a, Map<int, T> b) {
  if (a.length != b.length) return false;
  for (final entrada in a.entries) {
    if (b[entrada.key] != entrada.value) return false;
  }
  return true;
}
