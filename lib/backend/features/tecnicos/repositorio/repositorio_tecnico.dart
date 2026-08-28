import '../modelo/tecnico.dart';

/// Una página de técnicos junto al total de coincidencias.
///
/// [total] cuenta **todas** las filas que cumplen el filtro, no las de la
/// página: es lo que necesita el paginador para saber cuántas páginas hay.
class PaginaTecnicos {
  const PaginaTecnicos({required this.items, required this.total});

  final List<Tecnico> items;
  final int total;

  static const vacia = PaginaTecnicos(items: [], total: 0);
}

/// Criterios de filtrado que se aplican **en SQL**, no en memoria.
class FiltroTecnicos {
  const FiltroTecnicos({this.busqueda = '', this.activo});

  /// Coincide contra nombres, apellidos, documento o teléfono —todos ellos
  /// en `personas`.
  final String busqueda;

  /// `null` = todos; `true` = solo activos; `false` = solo inactivos.
  final bool? activo;
}

abstract interface class RepositorioTecnico {
  /// Catálogo completo, en vivo. Para quien necesita todos los técnicos
  /// —los selectores de otros módulos—, no la grilla paginada.
  Stream<List<Tecnico>> observarTodos();

  /// ¿Hay **otro técnico** con ese documento?
  ///
  /// Que la persona exista es otra pregunta —puede estar registrada solo como
  /// cliente—: eso lo responde `RepositorioPersona.buscarPorDocumento`.
  Future<bool> existeDocumento(String documento, {int? excluirId});

  Future<Tecnico> crear(Tecnico tecnico);

  Future<Tecnico> actualizar(Tecnico tecnico);

  Future<void> eliminar(int id);

  // Paginación — el filtrado y el conteo ocurren en la base de datos.

  /// Observa una página de técnicos que cumplen [filtro].
  ///
  /// [pagina] es de base cero. Re-emite cuando cambian los datos, igual que
  /// [observarTodos], pero trayendo solo [tamano] filas.
  Stream<PaginaTecnicos> observarPagina({
    required FiltroTecnicos filtro,
    required int pagina,
    required int tamano,
  });

  /// Observa cuántos técnicos hay en total y cuántos están activos.
  ///
  /// Sale de un `COUNT`, no de contar una lista en memoria.
  Stream<({int total, int activos})> observarResumen();
}
