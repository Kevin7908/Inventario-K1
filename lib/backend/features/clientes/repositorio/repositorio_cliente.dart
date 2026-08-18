import '../../motos/modelo/moto.dart';
import '../modelo/cliente.dart';

/// Filtros que el repositorio traduce a un `WHERE`.
///
/// Es un value object con igualdad estructural para que reabrir el stream con
/// el mismo filtro no cuente como cambio.
final class FiltroClientes {
  const FiltroClientes({this.busqueda = '', this.activo});

  /// Texto libre. Busca en nombres, apellidos, documento, teléfono, email y
  /// ciudad —todos ellos en `personas`.
  final String busqueda;

  /// `null` = todos; `true` = solo activos; `false` = solo inactivos.
  final bool? activo;

  @override
  bool operator ==(Object other) =>
      other is FiltroClientes &&
      other.busqueda == busqueda &&
      other.activo == activo;

  @override
  int get hashCode => Object.hash(busqueda, activo);
}

/// Un tramo del catálogo más el total real.
///
/// [total] cuenta todas las filas que cumplen el filtro, no las de la página:
/// sin él la paginación no sabría cuántas páginas hay.
final class PaginaClientes {
  const PaginaClientes({required this.items, required this.total});

  final List<Cliente> items;
  final int total;
}

/// Conteos del encabezado, resueltos con un solo `COUNT` por columna.
typedef ResumenClientes = ({int total, int conSaldo});

/// Estado de cuenta de un cliente, calculado sobre `deudores`.
///
/// No hay columna `alDia` en `clientes` a propósito: el saldo sale de las
/// deudas vivas del cliente, así que un campo guardado quedaría desfasado en
/// cuanto se registrara un pago desde el módulo de Deudores.
typedef SaldoCliente = ({int pendiente, int deudas});

abstract class RepositorioClientes {
  Stream<List<Cliente>> observarTodos();

  Future<List<Cliente>> obtenerTodos();

  Future<List<Cliente>> buscar(String query);

  Future<Cliente?> obtenerPorId(int id);

  /// Una página del catálogo. El `WHERE`, el `COUNT` y el `LIMIT` los resuelve
  /// SQLite.
  Stream<PaginaClientes> observarPagina({
    required FiltroClientes filtro,
    required int pagina,
    required int tamano,
  });

  Stream<ResumenClientes> observarResumen();

  /// Saldo pendiente de cada cliente que debe algo, indexado por id.
  ///
  /// Los clientes al día **no aparecen** en el mapa: quien lo consulte trata
  /// la ausencia como "al día".
  Stream<Map<int, SaldoCliente>> observarSaldos();

  /// ¿Hay **otro cliente** con ese documento?
  ///
  /// Distinto de que exista la persona: alguien puede estar registrado como
  /// técnico y no ser cliente todavía. Eso lo responde
  /// `RepositorioPersona.buscarPorDocumento`, y es lo que separa el error
  /// «ya es cliente» del aviso «ya está registrado como técnico».
  Future<bool> existeDocumento(String documento, {int? excluirId});

  Future<int> crear(Cliente cliente);

  Future<void> actualizar(Cliente cliente);

  Future<void> eliminar(int id);

  /// Guarda el cliente **y sus motos** en una sola transacción.
  ///
  /// Va junto porque una moto no existe sin dueño —`motos.cliente_id` es
  /// obligatorio— y porque si la segunda moto choca con una placa ya
  /// registrada no puede quedar el cliente creado con solo la primera.
  ///
  /// Las motos con `id == 0` se insertan; el resto se actualizan. Las que
  /// estaban y no vienen en [motos] se borran.
  ///
  /// Devuelve el id del cliente guardado.
  Future<int> guardarConMotos({
    required Cliente cliente,
    required List<Moto> motos,
  });
}
