import 'package:equatable/equatable.dart';

class Especializacion extends Equatable{
  final int id;
  final String nombre;
  final String? descripcion;

  const Especializacion({
    required this.id,
    required this.nombre,
    this.descripcion,
  });

  Especializacion copyWith({
    int? id,
    String? nombre,
    String? descripcion,
  }) {
    return Especializacion(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
    );
  }

  @override
  List<Object?> get props => [id, nombre, descripcion];

  @override
  String toString() {
    return 'Especializacion{id: $id, nombre: $nombre, descripcion: $descripcion}';
  }
}