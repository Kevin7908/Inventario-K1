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
/// - [codigo]: el SKU o la referencia, si la hay. En la factura de carta va en
///   su propia columna —es lo que el cliente cita para pedir el mismo repuesto
///   otra vez— y en la tirilla, pequeño bajo la descripción, que es donde cabe.
/// - [unidad]: en qué se mide («UND», «LT», «MT»). Se pinta junto a la
///   cantidad: «2 UND». Vacía, se omite.
/// - [detalle]: una nota bajo la descripción, para lo que no es un código: el
///   técnico que hizo el trabajo en una orden de servicio. Es un campo aparte
///   de [codigo] porque el código va en su propia columna de la factura y una
///   nota no: mezclarlos ponía «Técnico: Ana» bajo el rótulo «Código».
/// - [cantidad]: admite decimales (hay productos por litro y por metro).
/// - [precioUnitario], [subtotal]: en pesos enteros.
class LineaDocumento extends Equatable {
  const LineaDocumento({
    required this.descripcion,
    this.codigo,
    this.unidad = '',
    this.detalle,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  final String descripcion;
  final String? codigo;
  final String unidad;
  final String? detalle;
  final double cantidad;
  final int precioUnitario;
  final int subtotal;

  /// `true` si la línea tiene código que pintar.
  bool get tieneCodigo => (codigo ?? '').isNotEmpty;

  /// `true` si hay nota que pintar bajo la descripción.
  bool get tieneDetalle => (detalle ?? '').isNotEmpty;

  @override
  List<Object?> get props => [
        descripcion,
        codigo,
        unidad,
        detalle,
        cantidad,
        precioUnitario,
        subtotal,
      ];
}
