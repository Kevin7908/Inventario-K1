/// Una marca del catálogo de motos.
class MarcaMoto {
  const MarcaMoto({
    required this.id,
    required this.nombre,
    required this.activo,
    this.modelos = 0,
  });

  final int id;
  final String nombre;
  final bool activo;

  /// Cuántos modelos cuelgan de ella. Sale de un `COUNT` con `GROUP BY` en el
  /// repositorio (`REGLAS_BD.md` §5), no de recorrer una lista en la vista.
  final int modelos;
}

/// Un modelo concreto dentro de una marca.
class ModeloMoto {
  const ModeloMoto({
    required this.id,
    required this.marcaId,
    required this.nombre,
    required this.activo,
    this.cilindraje,
    this.marca,
  });

  final int id;
  final int marcaId;
  final String nombre;
  final bool activo;

  /// En cc. Nulo mientras el taller no lo sepa.
  final int? cilindraje;

  /// El nombre de la marca, inflado por el JOIN cuando el modelo se lista
  /// fuera de su marca (el selector de compatibilidades, por ejemplo).
  final String? marca;

  /// «Yamaha FZ 2.0», o «FZ 2.0» si se pinta dentro de su propia marca.
  String get nombreCompleto => marca == null ? nombre : '$marca $nombre';
}
