import 'package:equatable/equatable.dart';

class Tecnico extends Equatable {
  const Tecnico({
    this.id,
    this.cedula,
    required this.nombres,
    this.apellidos,
    this.telefono,
    this.email,
    this.especializacionId,
    this.salarioBase,
    required this.activo,
    required this.creadoEn,
  });

  final int? id;
  final String? cedula;
  final String nombres;
  final String? apellidos;
  final String? telefono;
  final String? email;
  final int? especializacionId;
  final double? salarioBase;
  final bool activo;
  final DateTime creadoEn;

  /// Nombre completo: "Nombres Apellidos" o sólo "Nombres".
  String get nombreCompleto =>
      apellidos != null && apellidos!.isNotEmpty
          ? '$nombres $apellidos'
          : nombres;

  String get iniciales {
    final partes = nombreCompleto.trim().split(RegExp(r'\s+'));
    if (partes.length == 1) return partes[0][0].toUpperCase();
    return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
  }

  Tecnico copyWith({
    int? id,
    String? cedula,
    String? nombres,
    String? apellidos,
    String? telefono,
    String? email,
    int? especializacionId,
    double? salarioBase,
    bool? activo,
    DateTime? creadoEn,
  }) {
    return Tecnico(
      id: id ?? this.id,
      cedula: cedula ?? this.cedula,
      nombres: nombres ?? this.nombres,
      apellidos: apellidos ?? this.apellidos,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      especializacionId: especializacionId ?? this.especializacionId,
      salarioBase: salarioBase ?? this.salarioBase,
      activo: activo ?? this.activo,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }

  @override
  List<Object?> get props => [
        id,
        cedula,
        nombres,
        apellidos,
        telefono,
        email,
        especializacionId,
        salarioBase,
        activo,
        creadoEn,
      ];
}