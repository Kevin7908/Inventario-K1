import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/tecnicos/modelo/tecnico.dart';
import '../../../../backend/features/tecnicos/repositorio/repositorio_tecnico.dart';
import '../../../../backend/features/tecnicos/repositorio/repositorio_tecnico_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../../../core/resultado.dart';
import '../../persona/provider/persona_provider.dart';
import '../../ordenes/provider/ordenes_providers.dart';
import '../../autenticacion/provider/auth_providers.dart';

// Repositorio

final repositorioTecnicoProvider = Provider<RepositorioTecnico>(
  (ref) => RepositorioTecnicoDrift(
    ref.watch(appDatabaseProvider),
    // Quién firma lo que este repositorio escriba. Es una dependencia
    // del constructor, no un registro global (`CLAUDE.md` §3).
    ref.watch(sesionActualProvider),
  ),
  name: 'repositorioTecnicoProvider',
);

// Estado

/// Estado del catálogo de técnicos: **solo la página visible**.
///
/// El filtrado, el conteo y el recorte los hace SQLite. Quien necesite todos
/// los técnicos —los selectores de otros módulos— usa
/// [catalogoTecnicosProvider].
final class TecnicosState {
  const TecnicosState({
    this.items = const [],
    this.total = 0,
    this.pagina = 0,
    this.tamanoPagina = 20,
    this.busqueda = '',
    this.filtroActivo,
  });

  /// Técnicos de la página actual.
  final List<Tecnico> items;

  /// Total de técnicos que cumplen el filtro, en todas las páginas.
  final int total;

  /// Página actual, de base cero.
  final int pagina;
  final int tamanoPagina;

  final String busqueda;

  /// `null` = todos; `true` = solo activos; `false` = solo inactivos.
  final bool? filtroActivo;

  int get totalPaginas =>
      total <= 0 ? 1 : (total + tamanoPagina - 1) ~/ tamanoPagina;

  bool get hayFiltro => busqueda.isNotEmpty || filtroActivo != null;

  /// Traduce los filtros de la interfaz a los que entiende el repositorio.
  FiltroTecnicos get filtro =>
      FiltroTecnicos(busqueda: busqueda, activo: filtroActivo);

  /// Centinela para distinguir "no tocar [filtroActivo]" de "ponerlo en null"
  /// (= quitar el filtro de estado), que con `??` serían lo mismo.
  static const Object _sinCambio = Object();

  TecnicosState copyWith({
    List<Tecnico>? items,
    int? total,
    int? pagina,
    int? tamanoPagina,
    String? busqueda,
    Object? filtroActivo = _sinCambio,
  }) =>
      TecnicosState(
        items:        items        ?? this.items,
        total:        total        ?? this.total,
        pagina:       pagina       ?? this.pagina,
        tamanoPagina: tamanoPagina ?? this.tamanoPagina,
        busqueda:     busqueda     ?? this.busqueda,
        filtroActivo: identical(filtroActivo, _sinCambio)
            ? this.filtroActivo
            : filtroActivo as bool?,
      );
}

// Notifier

class TecnicosNotifier extends AsyncNotifier<TecnicosState> {
  late final RepositorioTecnico _repo;
  StreamSubscription<PaginaTecnicos>? _sub;

  @override
  Future<TecnicosState> build() async {
    _repo = ref.watch(repositorioTecnicoProvider);
    ref.onDispose(() => _sub?.cancel());

    const inicial = TecnicosState();
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
  void _suscribir(TecnicosState estado) {
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

  void _aplicar(TecnicosState nuevo) {
    state = AsyncData(nuevo);
    _suscribir(nuevo);
  }

  // Filtros — todos vuelven a la primera página, porque el conjunto cambió.

  void buscar(String query) {
    final actual = state.value;
    if (actual == null) return;
    final trimmed = query.trim();
    if (actual.busqueda == trimmed) return;
    _aplicar(actual.copyWith(busqueda: trimmed, pagina: 0));
  }

  /// Filtra por estado. `null` quita el filtro y muestra todos.
  void filtrarPorActivo(bool? activo) {
    final actual = state.value;
    if (actual == null || actual.filtroActivo == activo) return;
    _aplicar(actual.copyWith(filtroActivo: activo, pagina: 0));
  }

  void irAPagina(int pagina) {
    final actual = state.value;
    if (actual == null || pagina == actual.pagina) return;
    if (pagina < 0 || pagina >= actual.totalPaginas) return;
    _aplicar(actual.copyWith(pagina: pagina));
  }

  // Mutaciones

  Future<Resultado> crear(Tecnico tecnico) async {
    final invalido = await _validar(tecnico);
    if (invalido != null) return invalido;

    try {
      await _repo.crear(tecnico.copyWith(creadoEn: DateTime.now()));
      return const Exito();
    } catch (e) {
      return Fallo(MotivoFallo.persistencia, 'Error al crear el técnico: $e');
    }
  }

  Future<Resultado> actualizar(Tecnico tecnico) async {
    final invalido = await _validar(tecnico, excluirId: tecnico.id);
    if (invalido != null) return invalido;

    try {
      await _repo.actualizar(tecnico);
      return const Exito();
    } catch (e) {
      return Fallo(
        MotivoFallo.persistencia,
        'Error al actualizar el técnico: $e',
      );
    }
  }

  Future<Resultado> eliminar(int id) async {
    try {
      await _repo.eliminar(id);
      return const Exito();
    } catch (e) {
      return Fallo(
        MotivoFallo.persistencia,
        'No se pudo eliminar el técnico: $e',
      );
    }
  }

  /// Reglas de negocio del alta y la edición. Viven en el notifier y no en el
  /// formulario para que el diálogo de otro módulo no pueda saltárselas.
  Future<Resultado?> _validar(Tecnico tecnico, {int? excluirId}) async {
    final nombres = tecnico.nombres.trim();
    if (nombres.isEmpty) {
      return const Fallo(
        MotivoFallo.validacion,
        'El nombre no puede estar vacío.',
      );
    }
    if (nombres.length < 2) {
      return const Fallo(
        MotivoFallo.validacion,
        'El nombre debe tener al menos 2 caracteres.',
      );
    }

    // Que la persona ya exista no es un error: puede estar registrada solo
    // como cliente, y en ese caso el repositorio reutiliza su fila de
    // `personas`. Lo que sí se rechaza es que ya sea técnico.
    final documento = tecnico.documento?.trim() ?? '';
    if (documento.isNotEmpty &&
        await _repo.existeDocumento(documento, excluirId: excluirId)) {
      return const Fallo(
        MotivoFallo.documentoDuplicado,
        'Ya existe un técnico con esa cédula.',
      );
    }

    return _telefonoLibre(tecnico.telefono, tecnico.personaId);
  }

  /// El teléfono es único en `personas`, así que el choque puede ser con
  /// cualquier rol. Es una comprobación de cortesía, para dar un mensaje que
  /// se entienda; la que impide de verdad es el `UNIQUE` de la tabla.
  Future<Resultado?> _telefonoLibre(String? telefono, int? personaId) async {
    final numero = telefono?.trim() ?? '';
    if (numero.isEmpty) return null;

    final dueno = await ref
        .read(repositorioPersonaProvider)
        .duenoDeTelefono(numero, excluirPersonaId: personaId);

    return dueno == null
        ? null
        : Fallo(
            MotivoFallo.telefonoDuplicado,
            'El teléfono $numero ya está registrado a nombre de $dueno.',
          );
  }
}

// Providers públicos

final tecnicosProvider = AsyncNotifierProvider<TecnicosNotifier, TecnicosState>(
  TecnicosNotifier.new,
  name: 'tecnicosProvider',
);

/// Catálogo completo de técnicos, en vivo.
///
/// Para lo que necesita todos: los selectores de técnico de cotizaciones,
/// facturas y órdenes. La grilla de Técnicos no lo usa — esa va paginada
/// contra la base de datos.
final catalogoTecnicosProvider = StreamProvider<List<Tecnico>>(
  name: 'catalogoTecnicosProvider',
  (ref) => ref.watch(repositorioTecnicoProvider).observarTodos(),
);

/// Técnicos de la página actual.
final tecnicosFiltradosProvider = Provider<List<Tecnico>>(
  name: 'tecnicosFiltradosProvider',
  (ref) => ref.watch(tecnicosProvider).value?.items ?? const [],
);

/// Conteos del encabezado, resueltos con un COUNT en SQL.
final tecnicosResumenProvider = StreamProvider<({int total, int activos})>(
  name: 'tecnicosResumenProvider',
  (ref) => ref.watch(repositorioTecnicoProvider).observarResumen(),
);

/// Cuántas órdenes distintas tiene asignadas cada técnico, indexado por id.
///
/// Sale de un `COUNT DISTINCT` sobre `ordenes_tareas`, no de recorrer las
/// órdenes en memoria. El `distinct` compara el contenido del mapa: Drift
/// re-emite ante cualquier cambio en la tabla de tareas, y sin esto la
/// grilla se reconstruiría aunque ningún conteo hubiera cambiado.
final conteoOrdenesPorTecnicoProvider = StreamProvider<Map<int, int>>(
  name: 'conteoOrdenesPorTecnicoProvider',
  (ref) => ref
      .watch(repositorioOrdenesProvider)
      .observarConteoTareasPorTecnico()
      .distinct(_mismoConteo),
);

bool _mismoConteo(Map<int, int> a, Map<int, int> b) {
  if (a.length != b.length) return false;
  for (final entrada in a.entries) {
    if (b[entrada.key] != entrada.value) return false;
  }
  return true;
}
