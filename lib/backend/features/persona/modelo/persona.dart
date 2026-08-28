import 'package:equatable/equatable.dart';

/// Clase de documento con la que se identifica una persona o una empresa.
///
/// El valor de [codigo] es el que viaja a la columna `personas.tipo_documento`
/// y el que valida su `CHECK`; [etiqueta] es lo que ve el usuario.
enum TipoDocumento {
  cc('CC', 'Cédula de ciudadanía'),
  nit('NIT', 'NIT'),
  ce('CE', 'Cédula de extranjería'),
  pa('PA', 'Pasaporte'),
  ti('TI', 'Tarjeta de identidad');

  const TipoDocumento(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  /// Traduce el texto guardado en la BD. Cae en [TipoDocumento.cc] si el valor
  /// no se reconoce, que es lo que hay en la inmensa mayoría de las filas.
  static TipoDocumento desdeCodigo(String? codigo) => values.firstWhere(
        (t) => t.codigo == codigo,
        orElse: () => TipoDocumento.cc,
      );
}

/// Deja el documento en la forma en que se guarda: sin puntos, guiones ni
/// espacios, y sin cadena vacía.
///
/// Existe un solo normalizador a propósito. Si cada formulario limpiara el
/// texto a su manera, «1.098.765-432» y «1098765432» serían dos personas
/// distintas y la tabla `personas` no serviría de nada.
String? normalizarDocumento(String? valor) {
  if (valor == null) return null;
  final limpio = valor.replaceAll(RegExp(r'[\s.\-]'), '');
  return limpio.isEmpty ? null : limpio;
}

/// Lo que toda persona expone, sea cliente, técnico o usuario.
///
/// Es el reflejo en el dominio de la tabla `personas`: la identidad se declara
/// una sola vez y [nombreCompleto] e [iniciales] se derivan aquí, no en cada
/// modelo —`Tecnico` los tenía copiados palabra por palabra.
///
/// `Proveedor` queda fuera a propósito: guarda razón social y NIT, y llamarlos
/// `nombres` y `documento` haría peor su código aunque compartan la misma
/// fila de `personas`.
abstract class Persona extends Equatable {
  const Persona();

  /// Id de la fila en `personas`. Es lo que comparten los distintos roles de
  /// una misma persona; `null` mientras no se haya guardado.
  int? get personaId;

  /// Cédula o NIT ya normalizado. Ver [normalizarDocumento].
  String? get documento;

  String get nombres;
  String? get apellidos;
  String? get telefono;
  String? get email;

  String get nombreCompleto {
    final ape = apellidos?.trim();
    return ape == null || ape.isEmpty ? nombres.trim() : '${nombres.trim()} $ape';
  }

  String get iniciales {
    final partes = nombreCompleto.trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
  }

  @override
  List<Object?> get props =>
      [personaId, documento, nombres, apellidos, telefono, email];
}

/// Una persona sin rol: lo que se lee y se escribe en `personas`.
///
/// Los modelos de rol (`Cliente`, `Tecnico`) exponen estos mismos campos
/// aplanados; esta clase es la que usan el repositorio de personas y el flujo
/// de «esta cédula ya está registrada».
final class DatosPersona extends Persona {
  const DatosPersona({
    this.personaId,
    this.tipoDocumento = TipoDocumento.cc,
    this.documento,
    required this.nombres,
    this.apellidos,
    this.telefono,
    this.email,
    this.direccion,
    this.ciudad,
  });

  @override
  final int? personaId;
  final TipoDocumento tipoDocumento;
  @override
  final String? documento;
  @override
  final String nombres;
  @override
  final String? apellidos;
  @override
  final String? telefono;
  @override
  final String? email;
  final String? direccion;
  final String? ciudad;

  @override
  List<Object?> get props => [...super.props, tipoDocumento, direccion, ciudad];
}
