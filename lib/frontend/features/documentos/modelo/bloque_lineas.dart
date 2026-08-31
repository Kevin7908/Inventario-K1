import 'package:equatable/equatable.dart';

/// Un grupo de líneas del documento, con su título opcional.
///
/// Existe porque una venta de taller no siempre es una lista plana: puede
/// llevar repuestos y mano de obra, y en el papel tienen que verse separados.
/// Un documento sencillo —el carrito del mostrador— usa **un solo bloque sin
/// título**, y entonces el encabezado de grupo no se pinta.
///
/// Parámetros:
/// - [titulo]: cabecera del grupo («Repuestos», «Servicios»). En `null` el
///   bloque se pinta sin separador.
/// - [lineas]: las líneas del grupo. Un bloque vacío no se pinta.
///
/// Ejemplo:
/// ```dart
/// BloqueLineas(titulo: 'Repuestos', lineas: [...])
/// ```
class BloqueLineas extends Equatable {
  const BloqueLineas({this.titulo, required this.lineas});

  final String? titulo;
  final List<LineaDocumento> lineas;

  bool get vacio => lineas.isEmpty;

  /// Lo que suman las líneas del bloque, para el subtotal por grupo.
  int get subtotal =>
      lineas.fold(0, (acumulado, linea) => acumulado + linea.subtotal);

  @override
  List<Object?> get props => [titulo, lineas];
}

/// Una línea del documento: qué, cuánto, a cómo y cuánto suma.
///
/// Parámetros:
/// - [descripcion]: lo que ve el cliente. Es el **snapshot** guardado en el
///   documento, no el nombre actual del catálogo: si mañana se renombra el
///   producto, la factura de ayer sigue diciendo lo que se vendió.
/// - [referencia]: SKU o código, si lo hay. Se pinta pequeño bajo la
///   descripción.
/// - [cantidad]: admite decimales (hay productos por litro y por metro).
/// - [precioUnitario], [subtotal]: en pesos enteros.
class LineaDocumento extends Equatable {
  const LineaDocumento({
    required this.descripcion,
    this.referencia,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  final String descripcion;
  final String? referencia;
  final double cantidad;
  final int precioUnitario;
  final int subtotal;

  @override
  List<Object?> get props => [
        descripcion,
        referencia,
        cantidad,
        precioUnitario,
        subtotal,
      ];
}
