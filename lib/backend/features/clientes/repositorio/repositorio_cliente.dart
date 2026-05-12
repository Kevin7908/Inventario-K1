
import '../modelo/cliente.dart';


abstract class RepositorioClientes {

  Stream<List<Cliente>> observarTodos();

  Future<List<Cliente>> obtenerTodos();

  Future<List<Cliente>> buscar(String query);

  Future<int> crear(Cliente cliente);

  Future<void> actualizar(Cliente cliente);

  Future<void> eliminar(int id);
}