// backend/features/proveedores/repositorio/repositorio_proveedores.dart

import 'package:inventario_k1/backend/features/proveedores/modelo/proveedor.dart';

// Contrato abstracto del repositorio de proveedores
// El ViewModel depende de esta abstracción, no de la implementación concreta
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
}
