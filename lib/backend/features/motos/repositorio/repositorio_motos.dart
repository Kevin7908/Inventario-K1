import '../modelo/moto.dart';

/// Motos de un cliente, resumidas para la tarjeta del catálogo.
///
/// [principal] es la etiqueta ya armada ("Pulsar NS200 · KMN-12C") de la
/// primera moto en orden alfabético; `null` si el cliente no tiene ninguna.
typedef ResumenMotosCliente = ({int cantidad, String? principal});

/// Filtros que el repositorio traduce a un `WHERE`.
///
/// Es un value object con igualdad estructural para que reabrir el stream con
/// el mismo filtro no cuente como cambio.
final class FiltroMotos {
  const FiltroMotos({this.busqueda = '', this.activo});

  /// Texto libre. Busca en marca, modelo, placa, color, chasis y **el nombre
  /// del dueño**, que llega por el JOIN con `clientes`.
  final String busqueda;

  /// `null` = todas; `true` = solo activas; `false` = solo dadas de baja.
  final bool? activo;

  @override
  bool operator ==(Object other) =>
      other is FiltroMotos &&
      other.busqueda == busqueda &&
      other.activo == activo;

  @override
  int get hashCode => Object.hash(busqueda, activo);
}

/// Un tramo del catálogo más el total real.
///
/// [total] cuenta todas las filas que cumplen el filtro, no las de la página:
/// sin él la paginación no sabría cuántas páginas hay.
final class PaginaMotos {
  const PaginaMotos({required this.items, required this.total});

  final List<Moto> items;
  final int total;
}

/// Conteos del encabezado, resueltos con un solo `COUNT` por columna.
///
/// [sinPlaca] no filtra nada: es un aviso de calidad de dato. Una moto sin
/// placa no se puede buscar por placa ni identificar en una orden, así que
/// conviene que el taller vea cuántas hay.
typedef ResumenMotos = ({int total, int activas, int sinPlaca});

abstract class RepositorioMotos {
  /// Stream reactivo con todas las motos + nombre del cliente (JOIN).
  Stream<List<Moto>> observarTodos();

  /// Stream filtrado por cliente.
  Stream<List<Moto>> observarPorCliente(int clienteId);

  Future<List<Moto>> obtenerTodos();

  /// Consulta puntual de las motos de un cliente, para precargar el
  /// formulario de edición sin abrir un stream.
  Future<List<Moto>> obtenerPorCliente(int clienteId);

  Future<List<Moto>> buscar(String query);

  /// Una página del catálogo. El `WHERE`, el `COUNT` y el `LIMIT` los resuelve
  /// SQLite.
  Stream<PaginaMotos> observarPagina({
    required FiltroMotos filtro,
    required int pagina,
    required int tamano,
  });

  Stream<ResumenMotos> observarResumen();

  /// Cuántas motos tiene cada cliente y cuál mostrar primero, indexado por
  /// `clienteId`.
  ///
  /// Sale de un `GROUP BY` en SQL, no de recorrer las motos en memoria.
  Stream<Map<int, ResumenMotosCliente>> observarResumenPorCliente();

  /// La moto ya registrada con esa placa, o `null` si la placa está libre.
  ///
  /// Devuelve la moto entera —con `nombreCliente` resuelto por el JOIN— para
  /// que el mensaje de error pueda decir **quién** es el dueño actual y no
  /// solo que la placa está ocupada.
  ///
  /// [excluirMotoId] deja fuera a la propia moto al editarla; sin eso,
  /// guardar sin tocar la placa se rechazaría a sí mismo.
  Future<Moto?> duenoDePlaca(String placa, {int? excluirMotoId});

  Future<int> crear(Moto moto);

  Future<void> actualizar(Moto moto);

  Future<void> eliminar(int id);
}
