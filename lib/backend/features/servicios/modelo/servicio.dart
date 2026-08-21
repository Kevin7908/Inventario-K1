import 'package:equatable/equatable.dart';

class Servicio extends Equatable {
  final int id;
  final String nombre;
  final String? descripcion;

  /// Precio de referencia del trabajo, en pesos enteros. `0` = sin definir.
  /// Precarga el campo al cotizar; no es el precio final de ningún documento.
  final int precioSugerido;

  final bool activo;
  final DateTime? creadoEn;

  const Servicio({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.precioSugerido = 0,
    required this.activo,
    this.creadoEn,
  });

  Servicio copyWith({
    int? id,
    String? nombre,
    String? descripcion,
    int? precioSugerido,
    bool? activo,
    DateTime? creadoEn,
  }) {
    return Servicio(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      precioSugerido: precioSugerido ?? this.precioSugerido,
      activo: activo ?? this.activo,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }

  @override
  List<Object?> get props =>
      [id, nombre, descripcion, precioSugerido, activo, creadoEn];

  @override
  String toString() =>
      'Servicio{id: $id, nombre: $nombre, activo: $activo}';
}