// El IVA se **suma** al precio, no va dentro: `ivaSobre` lo liquida.
//
// Es la aritmética más delicada del sistema y la tasa vale 0 en un taller
// recién instalado, así que se prueba contra `ivaSobreConTasa`, que recibe la
// tasa. Aparte se comprueba lo que la tasa configurada sí decide: que
// `ivaSobre` delegue en ella, que `hayIva` y `etiquetaIva` la sigan, y que
// valores absurdos se recorten.
//
// El caso que trajo este cambio está en el primer test: un producto de $10.000
// con la tasa en 19% se factura en $11.900. Hasta el 07/09/2026 la convención
// era la contraria —el precio traía el impuesto dentro— y ese mismo producto
// cerraba en $10.000 con $1.597 de IVA, que es lo que el taller reportó como
// mal calculado.
//
// La tasa es una global —ver el porqué en `core/iva_app.dart`—, así que cada
// test que la mueva la devuelve a 0 en su `tearDown`. Sin eso, el orden de los
// tests cambiaría los resultados.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/core/iva_app.dart';

void main() {
  group('sumarle el IVA a una base', () {
    test('al 19%: un producto de 10.000 se factura en 11.900', () {
      expect(ivaSobreConTasa(10000, 0.19), 1900);
      expect(10000 + ivaSobreConTasa(10000, 0.19), 11900);
    });

    test('no es extraerlo: de 10.000 el impuesto no son 1.597', () {
      // La convención vieja. Se deja escrito porque es exactamente el número
      // que aparecía en pantalla y por el que se cambió la regla.
      expect(ivaSobreConTasa(10000, 0.19), isNot(1597));
    });

    test('sumar y volver a extraer devuelve la misma base', () {
      // La propiedad que no se puede romper: si el redondeo se comiera un
      // peso, el impreso mostraría un total que no cuadra con sus renglones.
      for (final base in [1, 7, 999, 19999, 100000, 123457, 999999]) {
        expect(ivaCuadra(base, 0.19), isTrue, reason: 'falla con $base');
        expect(ivaCuadra(base, 0.05), isTrue, reason: 'falla con $base');
      }
    });

    test('nunca es negativo, ni sobre una base negativa', () {
      // Un documento recortado de más no puede generar impuesto a favor.
      for (final base in [-50000, -1, 0, 1, 3, 100, 50000]) {
        expect(ivaSobreConTasa(base, 0.19), greaterThanOrEqualTo(0));
      }
    });

    test('con tasa 0 el impuesto es 0, no una multiplicación por uno', () {
      expect(ivaSobreConTasa(50000, 0), 0);
      expect(ivaSobreConTasa(0, 0.19), 0);
    });
  });

  group('discriminar el IVA de un total que ya lo trae', () {
    // La inversa, para lo que hereda un total ya liquidado: la deuda que nace
    // de una orden cerrada a crédito. Volver a sumarle IVA lo cobraría dos
    // veces.
    test('al 19%: de 119.000 el impuesto contenido son 19.000', () {
      expect(ivaContenidoEnConTasa(119000, 0.19), 19000);
    });

    test('nunca devuelve más que el propio monto', () {
      for (final monto in [0, 1, 3, 100, 50000]) {
        final iva = ivaContenidoEnConTasa(monto, 0.19);
        expect(iva, lessThanOrEqualTo(monto));
        expect(iva, greaterThanOrEqualTo(0));
      }
    });

    test('es la inversa de sumarlo, no la misma función', () {
      expect(ivaSobreConTasa(119000, 0.19), 22610);
      expect(ivaContenidoEnConTasa(119000, 0.19), 19000);
    });
  });

  group('la función que usa la app', () {
    tearDown(() => configurarIva(0));

    test('delega en la de tasa explícita con la tasa configurada', () {
      configurarIva(19);
      for (final base in [0, 1000, 87654]) {
        expect(ivaSobre(base), ivaSobreConTasa(base, tasaIva));
        expect(ivaContenidoEn(base), ivaContenidoEnConTasa(base, tasaIva));
      }
    });

    test('sin tasa configurada no hay IVA en ninguna parte', () {
      expect(hayIva, isFalse);
      expect(ivaSobre(100000), 0);
      expect(totalConIva(100000), 100000);
      expect(baseSinIva(100000), 100000);
    });
  });

  group('la tasa se configura, no se compila', () {
    tearDown(() => configurarIva(0));

    test('el porcentaje que se teclea es el que se aplica', () {
      configurarIva(19);
      expect(tasaIva, 0.19);
      expect(porcentajeIva, 19);
      expect(hayIva, isTrue);
      expect(ivaSobre(100000), 19000);
      expect(totalConIva(100000), 119000);
    });

    test('la etiqueta del renglón sale de la tasa, no de una constante', () {
      configurarIva(19);
      expect(etiquetaIva, 'IVA (19%)');
      expect(etiquetaIvaIncluido, 'IVA (19%) incluido');
      configurarIva(5);
      expect(etiquetaIva, 'IVA (5%)');
    });

    test('volver a 0 apaga el IVA en todas partes', () {
      configurarIva(19);
      configurarIva(0);
      expect(hayIva, isFalse);
      expect(ivaSobre(100000), 0);
    });

    test('un valor absurdo se recorta en vez de romper el cálculo', () {
      // Una tasa negativa no significa nada y una por encima de 100 haría que
      // el impuesto valiera más que la mercancía. El campo de Configuración ya
      // lo evita, pero la garantía tiene que estar donde vive la tasa.
      expect(configurarIva(-30), 0);
      expect(configurarIva(250), 1.0);
      expect(porcentajeIva, 100);
    });
  });
}
