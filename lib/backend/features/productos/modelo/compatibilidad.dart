/// A qué moto le sirve un repuesto: una marca entera o un modelo concreto.
///
/// Una línea vale por lo uno o por lo otro, nunca por los dos. El `CHECK` de
/// `producto_compatibilidades` lo garantiza en la base; aquí se lee con
/// [esDeMarca].
class Compatibilidad {
  const Compatibilidad({
    required this.id,
    required this.productoId,
    required this.marca,
    this.marcaId,
    this.modeloId,
    this.modelo,
    this.cilindraje,
  });

  final int id;
  final int productoId;

  /// Puesto exactamente uno de los dos.
  final int? marcaId;
  final int? modeloId;

  /// Resueltos por el JOIN. [marca] siempre está —el modelo también sabe de
  /// qué marca es—; [modelo] y [cilindraje] solo cuando la línea es de modelo.
  final String marca;
  final String? modelo;
  final int? cilindraje;

  /// `true` cuando la línea vale para toda la marca.
  bool get esDeMarca => marcaId != null;

  /// «Yamaha (toda la marca)» o «Yamaha FZ 2.0».
  String get etiqueta =>
      esDeMarca ? '$marca (toda la marca)' : '$marca $modelo';
}
