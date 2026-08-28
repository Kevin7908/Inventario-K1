/// Tasa de IVA del negocio. **Única fuente de verdad de todo el sistema.**
///
/// Antes convivían tres constantes con valores distintos —esta en 0, y dos
/// `kTasaIva` en 0.19 (en `producto.dart` y en el repositorio de
/// cotizaciones)—, así que el mismo producto salía sin IVA por el punto de
/// venta y con 19% por una cotización. Ahora todo el cálculo pasa por aquí:
/// cambiar este número cambia el POS, las cotizaciones, las órdenes y los
/// productos a la vez.
///
/// Si vale 0, el IVA es 0 en todas partes y la interfaz **esconde** el renglón
/// en vez de mostrar un `$0` que solo estorba.
///
/// No confundir con el IVA **guardado** en cada documento (`cotizaciones.iva`,
/// `ventas.iva`): esos son el registro histórico de con qué tasa se cerró esa
/// operación y no se recalculan al cambiar esta constante.
const double kIva = 0.0;

/// `true` si hay que cobrar IVA. Evita repetir `kIva > 0` por toda la interfaz.
bool get hayIva => kIva > 0;

/// Cuánto IVA hay **dentro** de [montoConIva].
///
/// **Los precios del sistema llevan el IVA incluido.** Es la convención del
/// taller: el precio que se teclea en el catálogo, el que se ve en la tarjeta
/// y el que se cobra son el mismo número, y el IVA va dentro. De ahí se sigue
/// todo lo demás:
///
/// - el **descuento se resta del precio con IVA**, no de una base imponible.
///   Rebajar $10.000 rebaja $10.000 de lo que paga el cliente, que es lo único
///   que se puede prometer en el mostrador;
/// - el `total` de un documento es `subtotal - descuento`, sin sumarle nada;
/// - el IVA es **informativo**: se extrae del total con esta función para
///   poder discriminarlo en el impreso, no para agrandarlo.
///
/// Antes se hacía al revés —precios sin IVA y `total = base + iva`—, y el
/// descuento se aplicaba sobre la base: rebajar $10.000 le quitaba $11.900 al
/// cliente sin que nadie lo hubiera decidido.
///
/// Con la tasa en 0 devuelve 0, así que quien lo llame no necesita comprobar
/// [hayIva] antes.
int ivaIncluidoEn(num montoConIva) => ivaIncluidoEnConTasa(montoConIva, kIva);

/// [ivaIncluidoEn] con la tasa explícita.
///
/// Existe porque [kIva] es una constante de compilación: sin este parámetro,
/// la aritmética de extraer el IVA —que es lo más delicado de todo el cálculo—
/// solo se podría probar con la tasa en 0, que devuelve 0 y no prueba nada.
/// La app siempre llama a [ivaIncluidoEn]; esto es para los tests.
int ivaIncluidoEnConTasa(num montoConIva, double tasa) {
  if (tasa <= 0) return 0;
  final base = (montoConIva / (1 + tasa)).round();
  return (montoConIva - base).round();
}

/// La parte de [montoConIva] que no es impuesto: el total menos su IVA.
int baseSinIva(num montoConIva) =>
    (montoConIva - ivaIncluidoEn(montoConIva)).round();

/// Comprueba la propiedad que tiene que cumplir siempre el cálculo:
/// base + IVA vuelve a dar exactamente el monto, sin perder ni ganar un peso
/// por el redondeo. La usan los tests.
bool ivaCuadra(int montoConIva, double tasa) {
  final iva = ivaIncluidoEnConTasa(montoConIva, tasa);
  return (montoConIva - iva) + iva == montoConIva;
}

/// Etiqueta del renglón de IVA: "IVA (19%) incluido". Sale de [kIva], no a
/// mano. Dice "incluido" porque el renglón informa, no suma.
String get etiquetaIva => 'IVA (${(kIva * 100).toStringAsFixed(0)}%) incluido';
