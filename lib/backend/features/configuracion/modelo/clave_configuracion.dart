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

  /// Porcentaje entero: `19` es 19%.
  ///
  /// La lee `main()` al arrancar y la aplica con `configurarIva`, que es lo
  /// que hace que el POS, las cotizaciones y las órdenes calculen todos con la
  /// misma tasa.
  ///
  /// **La clave `moneda` se fue el día que esta se conectó.** Guardaba `'COP'`
  /// y no la leía nadie —`core/formato.dart` fija el peso colombiano en un
  /// solo sitio—, y una clave que se puede cambiar sin que cambie nada es peor
  /// que no ofrecerla. Si algún día hay que vender en otra moneda, lo que se
  /// agrega no es esta clave de vuelta sino decimales y separador por moneda
  /// en `formato.dart`.
  ivaPorcentaje('iva_porcentaje', '0'),

  /// En qué papel salen los impresos: `CARTA`, `TIRILLA80` o `TIRILLA58`.
  ///
  /// Es el formato **del taller**, el que sale sin preguntar. El diálogo de
  /// vista previa deja cambiarlo para una impresión suelta —la orden que se
  /// entrega con la moto va en carta aunque la caja imprima tirilla todo el
  /// día—, pero eso no toca esta clave.
  ///
  /// Los valores son los de `FormatoImpreso.codigo`, en MAYÚSCULAS como todo
  /// enum guardado (`REGLAS_BD.md` §2). Uno que no se reconozca cae en carta,
  /// que es el papel que todo taller tiene.
  formatoImpresion('formato_impresion', 'CARTA'),

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
