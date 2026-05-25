import 'package:equatable/equatable.dart';

class Servicio extends Equatable {
  final int id;
  final String nombre;
  final String? descripcion;
  final bool activo;
  final String? creadoEn;

  const Servicio({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.activo,
    this.creadoEn,
  });

  Servicio copyWith({
    int? id,
    String? nombre,
    String? descripcion,
    bool? activo,
    String? creadoEn,
  }) {
    return Servicio(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      activo: activo ?? this.activo,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }

  @override
  List<Object?> get props => [id, nombre, descripcion, activo, creadoEn];

  @override
  String toString() =>
      'Servicio{id: $id, nombre: $nombre, activo: $activo}';
}