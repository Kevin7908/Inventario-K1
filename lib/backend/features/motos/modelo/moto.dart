class Moto {
  final int id;
  final int clienteId;

  // Datos básicos (hydrated desde JOIN con clientes)
  final String? nombreCliente; // Se infla en el mapper

  final String? placa;
  final String marca;
  final String modelo;
  final int? anio;
  final int? cilindraje;
  final String? color;
  final String? numeroMotor;
  final String? notas;
  final bool activo;
  final DateTime creadoEn;
  final DateTime actualizadoEn;

  const Moto({
    required this.id,
    required this.clienteId,
    this.nombreCliente,
    this.placa,
    required this.marca,
    required this.modelo,
    this.anio,
    this.cilindraje,
    this.color,
    this.numeroMotor,
    this.notas,
    required this.activo,
    required this.creadoEn,
    required this.actualizadoEn,
  });

  /// Nombre de presentación: "MARCA MODELO (PLACA)"
  String get nombreDisplay {
    final base = '$marca $modelo';
    if (placa != null && placa!.isNotEmpty) return '$base · $placa';
    return base;
  }

  /// Iniciales para el avatar (primera letra de marca + modelo)
  String get iniciales {
    final m = marca.isNotEmpty ? marca[0].toUpperCase() : '';
    final mo = modelo.isNotEmpty ? modelo[0].toUpperCase() : '';
    return '$m$mo';
  }

  Moto copyWith({
    int? id,
    int? clienteId,
    String? nombreCliente,
    String? placa,
    String? marca,
    String? modelo,
    int? anio,
    int? cilindraje,
    String? color,
    String? numeroMotor,
    String? notas,
    bool? activo,
    DateTime? creadoEn,
    DateTime? actualizadoEn,
  }) {
    return Moto(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      nombreCliente: nombreCliente ?? this.nombreCliente,
      placa: placa ?? this.placa,
      marca: marca ?? this.marca,
      modelo: modelo ?? this.modelo,
      anio: anio ?? this.anio,
      cilindraje: cilindraje ?? this.cilindraje,
      color: color ?? this.color,
      numeroMotor: numeroMotor ?? this.numeroMotor,
      notas: notas ?? this.notas,
      activo: activo ?? this.activo,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    );
  }
}