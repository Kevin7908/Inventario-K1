import 'package:equatable/equatable.dart';

abstract class Persona extends Equatable {
  String get nombres;
  String? get apellidos;
  String? get telefono;
  String? get email;

  const Persona(); 

  String get nombreCompleto =>
      [nombres, apellidos].where((e) => e != null && e.isNotEmpty).join(' ');

  String get iniciales {
    final partes = nombreCompleto.trim().split(' ');
    if (partes.length >= 2) {
      return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
    }
    return nombreCompleto.isNotEmpty ? nombreCompleto[0].toUpperCase() : '?';
  }

  @override
  List<Object?> get props => [nombres, apellidos, telefono, email];
}