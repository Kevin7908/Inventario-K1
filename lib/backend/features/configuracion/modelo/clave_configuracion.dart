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
  ivaPorcentaje('iva_porcentaje', '0'),

  /// Cuántos meses de bitácora conserva el taller antes de poder podarla.
  ///
  /// **Nunca por debajo de 24**, y eso no lo decide esta clave: la guarda de
  /// `guardas_sql.dart` rechaza cualquier `DELETE` sobre un renglón de menos
  /// de dos años, así que un valor menor no acortaría nada —solo haría que la
  /// poda no borrara nada—. Por eso el repositorio lo recorta a ese piso.
  /// Subirlo sí sirve: un taller que quiera guardar cinco años pone `60`.
  mesesBitacora('meses_bitacora', '24');

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
