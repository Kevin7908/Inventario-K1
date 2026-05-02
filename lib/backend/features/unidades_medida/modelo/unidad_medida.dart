// Modelo puro de dominio para Unidad de Medida (sin dependencia de Drift)
class UnidadMedida {
  final int? id;
  final String nombre;
  final String abreviatura;
  final String tipo;
  final String? descripcion;
  final DateTime creadoEn;
  final DateTime actualizadoEn;

  const UnidadMedida({
    this.id,
    required this.nombre,
    required this.abreviatura,
    this.tipo = 'unidad',
    this.descripcion,
    required this.creadoEn,
    required this.actualizadoEn,
  });

  // Constructor de copia para actualizaciones inmutables
  UnidadMedida copyWith({
    int? id,
    String? nombre,
    String? abreviatura,
    String? tipo,
    String? descripcion,
    DateTime? creadoEn,
    DateTime? actualizadoEn,
  }) {
    return UnidadMedida(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      abreviatura: abreviatura ?? this.abreviatura,
      tipo: tipo ?? this.tipo,
      descripcion: descripcion ?? this.descripcion,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    );
  }

  // Tipos disponibles de unidad de medida
  static const List<String> tiposDisponibles = [
    'unidad',
    'peso',
    'volumen',
    'longitud',
    'area',
    'tiempo',
    'otro',
  ];

  @override
  String toString() => 'UnidadMedida(id: $id, nombre: $nombre, abreviatura: $abreviatura)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnidadMedida && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
