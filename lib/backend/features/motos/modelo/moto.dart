/// La moto de un cliente, con lo que hace falta para pintarla ya resuelto.
///
/// **[marcaId] y [modeloId] son lo que se guarda; [marca], [modelo] y
/// [cilindraje] los infla el JOIN**, igual que [nombreCliente]. No es el dato
/// repetido que prohíbe `REGLAS_BD.md` §1.1: en la base solo están las FK, y
/// estos tres campos son la traducción para la vista, que no tiene por qué
/// consultar el catálogo de marcas para escribir un título.
class Moto {
  final int id;
  final int clienteId;

  // Datos básicos (hydrated desde JOIN con clientes)
  final String? nombreCliente; // Se infla en el mapper

  final String? placa;

  /// Lo que de verdad guarda la fila.
  final int marcaId;
  final int? modeloId;

  /// Resueltos por el JOIN con `marcas_moto` y `modelos_moto`.
  ///
  /// [modelo] es nulo cuando la moto se registró sin modelo catalogado, que es
  /// el caso que la columna admite a propósito: en el mostrador la marca
  /// siempre se sabe y el modelo exacto a veces no.
  ///
  /// [cilindraje] viene del **modelo**, no del ejemplar: todas las Boxer CT100
  /// son de 100 cc. Sin modelo, no hay cilindraje que mostrar.
  final String marca;
  final String? modelo;
  final int? cilindraje;

  final int? anio;
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
    required this.marcaId,
    required this.marca,
    this.modeloId,
    this.modelo,
    this.cilindraje,
    this.anio,
    this.color,
    this.numeroMotor,
    this.notas,
    required this.activo,
    required this.creadoEn,
    required this.actualizadoEn,
  });

  /// Marca y modelo juntos, saltándose el modelo si no lo hay.
  String get descripcionCorta =>
      modelo == null || modelo!.isEmpty ? marca : '$marca $modelo';

  /// Nombre de presentación: "MARCA MODELO · PLACA"
  String get nombreDisplay {
    final base = descripcionCorta;
    if (placa != null && placa!.isNotEmpty) return '$base · $placa';
    return base;
  }

  /// Iniciales para el avatar (primera letra de marca + modelo)
  String get iniciales {
    final m = marca.isNotEmpty ? marca[0].toUpperCase() : '';
    final mo = (modelo?.isNotEmpty ?? false) ? modelo![0].toUpperCase() : '';
    return '$m$mo';
  }

  Moto copyWith({
    int? id,
    int? clienteId,
    String? nombreCliente,
    String? placa,
    int? marcaId,
    String? marca,
    int? modeloId,
    String? modelo,
    int? cilindraje,
    int? anio,
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
      marcaId: marcaId ?? this.marcaId,
      marca: marca ?? this.marca,
      modeloId: modeloId ?? this.modeloId,
      modelo: modelo ?? this.modelo,
      cilindraje: cilindraje ?? this.cilindraje,
      anio: anio ?? this.anio,
      color: color ?? this.color,
      numeroMotor: numeroMotor ?? this.numeroMotor,
      notas: notas ?? this.notas,
      activo: activo ?? this.activo,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    );
  }
}
