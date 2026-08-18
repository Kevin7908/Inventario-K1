/// Las claves que admite la tabla `configuracion`.
///
/// Existe para que nadie escriba `'nit'` a mano en un sitio y `'NIT'` en otro:
/// con clave-valor, un typo no da error, da un dato que no aparece.
enum ClaveConfiguracion {
  nombreNegocio('nombre_negocio', 'Taller de Motos'),
  nit('nit', ''),
  direccion('direccion', ''),
  telefono('telefono', ''),
  ciudad('ciudad', ''),
  moneda('moneda', 'COP'),

  /// Porcentaje entero: `19` es 19%.
  ivaPorcentaje('iva_porcentaje', '0');

  const ClaveConfiguracion(this.clave, this.porDefecto);

  /// Lo que va en la columna `clave`.
  final String clave;

  /// Lo que vale mientras nadie la haya configurado.
  final String porDefecto;

  static ClaveConfiguracion? desdeClave(String clave) {
    for (final c in values) {
      if (c.clave == clave) return c;
    }
    return null;
  }
}
