// Modelo puro de dominio para Categoría (sin dependencia de Drift)
class Categoria {
  final int? id;
  final String nombre;
  final String? descripcion;
  final String colorHex;
  final String icono;
  final DateTime creadoEn;
  final DateTime actualizadoEn;

  // Número de productos asociados (calculado, no persistido)
  final int totalProductos;

  const Categoria({
    this.id,
    required this.nombre,
    this.descripcion,
    this.colorHex = '#3B82F6',
    this.icono = 'category',
    required this.creadoEn,
    required this.actualizadoEn,
    this.totalProductos = 0,
  });

  // Constructor de copia para actualizaciones inmutables
  Categoria copyWith({
    int? id,
    String? nombre,
    String? descripcion,
    String? colorHex,
    String? icono,
    DateTime? creadoEn,
    DateTime? actualizadoEn,
    int? totalProductos,
  }) {
    return Categoria(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      colorHex: colorHex ?? this.colorHex,
      icono: icono ?? this.icono,
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
