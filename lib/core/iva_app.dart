/// Tasa de IVA del negocio. **Única fuente de verdad de todo el sistema.**
///
/// Antes convivían tres constantes con valores distintos —esta en 0, y dos
/// `kTasaIva` en 0.19 (en `producto.dart` y en el repositorio de
/// cotizaciones)—, así que el mismo producto salía sin IVA por el punto de
/// venta y con 19% por una cotización. Ahora todo el cálculo pasa por aquí:
/// cambiar este número cambia el POS, las cotizaciones y los productos a la vez.
///
/// Si vale 0, el IVA es 0 en todas partes y la interfaz **esconde** el renglón
/// en vez de mostrar un `$0` que solo estorba.
///
/// No confundir con el IVA **guardado** en cada documento (`cotizaciones.iva`,
/// `facturas.iva`): esos son el registro histórico de con qué tasa se cerró esa
/// operación y no se recalculan al cambiar esta constante.
const double kIva = 0.0;

/// `true` si hay que cobrar IVA. Evita repetir `kIva > 0` por toda la interfaz.
bool get hayIva => kIva > 0;

/// IVA que le corresponde a un importe, redondeado al peso.
///
/// Los montos del sistema son enteros (pesos sin decimales, ver §6 de las
/// reglas), así que el redondeo va aquí y no en cada llamador.
int ivaDe(num base) => (base * kIva).round();

/// Etiqueta del renglón de IVA: "IVA (19%)". Sale de [kIva], no a mano.
String get etiquetaIva => 'IVA (${(kIva * 100).toStringAsFixed(0)}%)';
