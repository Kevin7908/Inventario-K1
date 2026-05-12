import '../modelo/moto.dart';

abstract class RepositorioMotos {
  /// Stream reactivo con todas las motos + nombre del cliente (JOIN).
  Stream<List<Moto>> observarTodos();

  /// Stream filtrado por cliente.
  Stream<List<Moto>> observarPorCliente(int clienteId);

  Future<List<Moto>> obtenerTodos();

  Future<List<Moto>> buscar(String query);

  Future<int> crear(Moto moto);

  Future<void> actualizar(Moto moto);

  Future<void> eliminar(int id);
}