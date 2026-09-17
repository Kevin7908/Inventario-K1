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
/// vuelve a aplicar al guardar. El valor por defecto es 0: un taller que no
/// factura IVA no tiene nada que hacer.
///
/// Si vale 0, el IVA es 0 en todas partes y la interfaz **esconde** el renglón
/// en vez de mostrar un `$0` que solo estorba.
///
/// ## El precio del catálogo es la base gravable
///
/// **El IVA se suma al precio, no va dentro.** El precio que se teclea en el
/// catálogo es lo que el taller cobra por la mercancía; el impuesto se le
/// agrega al facturar. De ahí se sigue todo lo demás:
///
/// - el subtotal de un documento es la suma de sus líneas, sin impuesto;
/// - el **descuento se resta antes del IVA**, que es como se liquida en
///   Colombia: rebajar $10.000 baja también el impuesto que esos $10.000
///   habrían generado;
/// - el `total` es `subtotal − descuento + iva`.
///
/// Un producto de $10.000 con la tasa en 19% factura $11.900. Hasta el
/// 07/09/2026 la convención era la contraria —los precios traían el IVA
/// dentro y el renglón solo lo discriminaba—, así que ese mismo producto
/// cerraba en $10.000 y el impuesto salía $1.597. El taller factura sumando.
///
/// ## Dos funciones, porque hay dos preguntas
///
/// - [ivaSobre] es la de facturar: cuánto impuesto **se le agrega** a una base.
///   La usan el POS, las cotizaciones y las órdenes.
/// - [ivaContenidoEn] es la de discriminar: cuánto impuesto **ya trae dentro**
///   un importe que se cerró con IVA. La usa lo que hereda un total ya
///   liquidado —la deuda que nace de una orden cerrada a crédito—, donde
///   volver a sumar cobraría el impuesto dos veces.
///
/// No son dos vocabularios: las dos salen de la misma [tasaIva] y una es la
/// inversa exacta de la otra. Lo que distingue cuál va es si el importe que se
/// tiene delante es base o es total.
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
/// convertiría el impuesto en más que la mercancía.
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

/// Cuánto IVA hay que **sumarle** a [base].
///
/// Es la función de facturar: la base es el subtotal del documento ya
/// descontado, y lo que devuelve es el renglón que se le agrega para llegar al
/// total.
///
/// Con la tasa en 0 devuelve 0, así que quien lo llame no necesita comprobar
/// [hayIva] antes. Con una base negativa devuelve 0: un documento no puede
/// generar impuesto a favor por haberse recortado de más.
int ivaSobre(num base) => ivaSobreConTasa(base, _tasa);

/// [ivaSobre] con la tasa explícita.
///
/// Existe para poder probar la aritmética —que es lo más delicado de todo el
/// cálculo— con varias tasas dentro del mismo test, sin tener que mover la
/// global y acordarse de dejarla como estaba.
int ivaSobreConTasa(num base, double tasa) {
  if (tasa <= 0 || base <= 0) return 0;
  return (base * tasa).round();
}

/// El total de [base] con su IVA sumado: lo que paga el cliente.
int totalConIva(num base) => base.round() + ivaSobre(base);

/// Cuánto IVA va **dentro** de [montoConIva].
///
/// La inversa de [ivaSobre], para los importes que ya se cerraron con el
/// impuesto sumado: una deuda que nace de una orden a crédito hereda el total
/// de esa orden, y volver a aplicarle [ivaSobre] cobraría dos veces.
///
/// Cumple `ivaContenidoEn(totalConIva(base)) == ivaSobre(base)` salvo por el
/// peso del redondeo, que es lo que comprueba [ivaCuadra].
int ivaContenidoEn(num montoConIva) =>
    ivaContenidoEnConTasa(montoConIva, _tasa);

/// [ivaContenidoEn] con la tasa explícita.
int ivaContenidoEnConTasa(num montoConIva, double tasa) {
  if (tasa <= 0 || montoConIva <= 0) return 0;
  final base = (montoConIva / (1 + tasa)).round();
  return (montoConIva - base).round();
}

/// La parte de [montoConIva] que no es impuesto: el total menos su IVA.
int baseSinIva(num montoConIva) =>
    (montoConIva - ivaContenidoEn(montoConIva)).round();

/// Comprueba la propiedad que tiene que cumplir siempre el cálculo: sumar el
/// IVA a una base y volver a sacárselo devuelve la misma base, sin perder ni
/// ganar un peso por el redondeo. La usan los tests.
bool ivaCuadra(int base, double tasa) {
  final iva = ivaSobreConTasa(base, tasa);
  final total = base + iva;
  return total - ivaContenidoEnConTasa(total, tasa) == base ||
      // Un peso de diferencia es inevitable cuando la base no es divisible por
      // la tasa: lo que no puede pasar es que se pierdan más.
      (total - ivaContenidoEnConTasa(total, tasa) - base).abs() <= 1;
}

/// Etiqueta del renglón de IVA: «IVA (19%)». Sale de [tasaIva], no a mano.
String get etiquetaIva => 'IVA ($porcentajeIva%)';

/// Etiqueta del renglón cuando el impuesto ya venía dentro del importe, como
/// en la deuda que hereda el total de una orden cerrada: «IVA (19%) incluido».
///
/// Es otra etiqueta y no la misma porque dicen cosas distintas: una anuncia lo
/// que se suma, la otra desglosa lo que ya se cobró.
String get etiquetaIvaIncluido => 'IVA ($porcentajeIva%) incluido';
