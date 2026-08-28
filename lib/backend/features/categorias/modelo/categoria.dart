/// Modelo puro de dominio para Categoría (sin dependencia de Drift).
///
/// **Sin color ni ícono**: cómo se pinta una categoría lo decide la vista con
/// los tokens de `ColoresApp`. Ver el docstring de `TablaCategoria`.
class Categoria {
  final int? id;
  final String nombre;
  final String? descripcion;
  final DateTime creadoEn;
  final DateTime actualizadoEn;

  // Número de productos asociados (calculado, no persistido)
  final int totalProductos;

  const Categoria({
    this.id,
    required this.nombre,
    this.descripcion,
    required this.creadoEn,
    required this.actualizadoEn,
    this.totalProductos = 0,
  });

  // Constructor de copia para actualizaciones inmutables
  Categoria copyWith({
    int? id,
    String? nombre,
    String? descripcion,
    DateTime? creadoEn,
    DateTime? actualizadoEn,
    int? totalProductos,
  }) {
    return Categoria(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
      totalProductos: totalProductos ?? this.totalProductos,
    );
  }

  @override
  String toString() => 'Categoria(id: $id, nombre: $nombre)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Categoria && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
