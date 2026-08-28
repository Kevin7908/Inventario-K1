// backend/features/proveedores/repositorio/repositorio_proveedores.dart

import 'package:inventario_k1/backend/features/proveedores/modelo/proveedor.dart';

/// Una página de proveedores junto al total de coincidencias.
///
/// [total] cuenta **todas** las filas que cumplen el filtro, no las de la
/// página: es lo que necesita el paginador para saber cuántas páginas hay.
class PaginaProveedores {
  const PaginaProveedores({required this.items, required this.total});

  final List<Proveedor> items;
  final int total;

  static const vacia = PaginaProveedores(items: [], total: 0);
}

/// Criterios de filtrado que se aplican **en SQL**, no en memoria.
class FiltroProveedores {
  const FiltroProveedores({this.busqueda = '', this.activo});

  /// Coincide contra nombre, NIT, ciudad o persona de contacto.
  final String busqueda;

  /// `null` = todos; `true` = solo activos; `false` = solo inactivos.
  final bool? activo;
}

// Contrato abstracto del repositorio de proveedores
// El notifier depende de esta abstracción, no de la implementación concreta
abstract class RepositorioProveedores {
  // Observar todos los proveedores
  Stream<List<Proveedor>> observarTodas();

  // Obtener un proveedor por su ID
  Future<Proveedor?> obtenerPorId(int id);

  // Buscar proveedores por nombre
  Future<List<Proveedor>> buscarPorNombre(String consulta);

  // Crear un nuevo proveedor
  Future<Proveedor> crear(Proveedor proveedor);

  // Actualizar un proveedor existente
  Future<Proveedor> actualizar(Proveedor proveedor);

  // Eliminar un proveedor por su ID
  Future<void> eliminar(int id);

  // Verificar si el nombre ya existe (para validación)
  Future<bool> existeNombre(String nombre, {int? excludirId});

  // Verificar si el NIT/Cédula ya existe (para validación)
  Future<bool> existeNit(String nit, {int? excludirId});

  // Paginación — el filtrado y el conteo ocurren en la base de datos.

  /// Observa una página de proveedores que cumplen [filtro].
  ///
  /// [pagina] es de base cero. Re-emite cuando cambian los datos, igual que
  /// [observarTodas], pero trayendo solo [tamano] filas.
  Stream<PaginaProveedores> observarPagina({
    required FiltroProveedores filtro,
    required int pagina,
    required int tamano,
  });

  /// Observa cuántos proveedores hay en total y cuántos están activos.
  ///
  /// Sale de un `COUNT`, no de contar una lista en memoria.
  Stream<({int total, int activos})> observarResumen();
}
