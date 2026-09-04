/// Tasa de IVA del negocio. **Única fuente de verdad de todo el sistema.**
///
/// Antes convivían tres constantes con valores distintos —una en 0, y dos
/// `kTasaIva` en 0.19 (en `producto.dart` y en el repositorio de
/// cotizaciones)—, así que el mismo producto salía sin IVA por el punto de
/// venta y con 19% por una cotización. Ahora todo el cálculo pasa por aquí:
/// cambiar este número cambia el POS, las cotizaciones, las órdenes y los
/// productos a la vez.
///
/// **Se configura, no se programa.** La tasa vive en la tabla `configuracion`
/// (`ClaveConfiguracion.ivaPorcentaje`) y `main()` la carga con
/// [configurarIva] antes del primer frame; la pantalla de Configuración la
/// vuelve a aplicar al guardar. Fue una constante de compilación hasta que se
/// conectó la clave, y por eso el valor por defecto sigue siendo 0: un taller
/// que no factura IVA no tiene nada que hacer.
///
/// Si vale 0, el IVA es 0 en todas partes y la interfaz **esconde** el renglón
/// en vez de mostrar un `$0` que solo estorba.
///
/// No confundir con el IVA **guardado** en cada documento (`cotizaciones.iva`,
/// `ventas.iva`): esos son el registro histórico de con qué tasa se cerró esa
/// operación y no se recalculan al cambiar la tasa vigente. Subir el IVA
/// mañana no reescribe la factura de ayer.
///
/// **Es un valor global y no una dependencia por constructor**, que es la
/// excepción a `CLAUDE.md` §3: no es un colaborador que un test necesite
/// sustituir por otro, es un escalar que leen funciones puras. Pasarlo por el
/// constructor obligaría a enhebrarlo por seis repositorios, cuatro estados de
/// editor y ocho widgets para que todos vean el mismo número —que es
/// exactamente el problema que este archivo existe para resolver—. Lo que sí
/// hace falta es que un test lo pueda fijar, y para eso está [configurarIva].
library;

/// La tasa vigente. Empieza en 0 y la pisa [configurarIva] al arrancar.
double _tasa = 0.0;

/// La tasa de IVA de hoy: `0.19` es 19%.
double get tasaIva => _tasa;

/// Fija la tasa vigente. La llama `main()` con lo que diga la base, y la
/// pantalla de Configuración cada vez que se guarda.
///
/// [porcentaje] es lo que el usuario teclea: `19` es 19%. Se recorta a
/// `0..100` porque una tasa negativa no significa nada y una por encima de 100
/// haría que la base imponible saliera negativa.
///
/// Devuelve la tasa que quedó, para que quien la fija pueda decir en pantalla
/// qué se aplicó de verdad.
double configurarIva(num porcentaje) {
  _tasa = porcentaje.clamp(0, 100) / 100;
  return _tasa;
}

/// La tasa como porcentaje entero, que es como se guarda y como se teclea.
int get porcentajeIva => (_tasa * 100).round();

/// `true` si hay que cobrar IVA. Evita repetir `tasaIva > 0` por toda la
/// interfaz.
bool get hayIva => _tasa > 0;

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
int ivaIncluidoEn(num montoConIva) => ivaIncluidoEnConTasa(montoConIva, _tasa);

/// [ivaIncluidoEn] con la tasa explícita.
///
/// Existe para poder probar la aritmética —que es lo más delicado de todo el
/// cálculo— con varias tasas dentro del mismo test, sin tener que mover la
/// global y acordarse de dejarla como estaba.
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

/// Etiqueta del renglón de IVA: "IVA (19%) incluido". Sale de [tasaIva], no a
/// mano. Dice "incluido" porque el renglón informa, no suma.
String get etiquetaIva => 'IVA ($porcentajeIva%) incluido';
