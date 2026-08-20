// El IVA va **dentro** del precio, no encima: `ivaIncluidoEn` lo extrae.
//
// Es la aritmética más delicada del sistema y `kIva` vale 0 hoy, así que con
// la constante real ningún test probaría nada. Por eso se prueba contra
// `ivaIncluidoEnConTasa`, que recibe la tasa, y aparte se comprueba que la
// función que usa la app delega en ella.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/core/iva_app.dart';

void main() {
  group('extraer el IVA de un precio que ya lo trae', () {
    test('al 19%: de 119.000 el impuesto son 19.000', () {
      expect(ivaIncluidoEnConTasa(119000, 0.19), 19000);
    });

    test('la base más el IVA reconstruyen el precio, al peso', () {
      // Es la propiedad que no se puede romper: si el redondeo se comiera un
      // peso, el impreso mostraría un total que no cuadra con sus renglones.
      for (final monto in [1, 7, 999, 19999, 100000, 123457, 999999]) {
        expect(ivaCuadra(monto, 0.19), isTrue, reason: 'falla con $monto');
        expect(ivaCuadra(monto, 0.05), isTrue, reason: 'falla con $monto');
      }
    });

    test('nunca devuelve más que el propio monto', () {
      for (final monto in [0, 1, 3, 100, 50000]) {
        final iva = ivaIncluidoEnConTasa(monto, 0.19);
        expect(iva, lessThanOrEqualTo(monto));
        expect(iva, greaterThanOrEqualTo(0));
      }
    });

    test('con tasa 0 el impuesto es 0, no una división por uno', () {
      expect(ivaIncluidoEnConTasa(50000, 0), 0);
      expect(ivaIncluidoEnConTasa(0, 0.19), 0);
    });

    test('extraer no es lo mismo que sumar: 19% de 119.000 sería 22.610', () {
      // El error que este modelo evita. Con el cálculo viejo —precio sin IVA y
      // total = base + iva— un descuento sobre la base le quitaba al cliente
      // un 19% más de lo que decía el renglón.
      expect(ivaIncluidoEnConTasa(119000, 0.19), isNot(22610));
      expect(ivaIncluidoEnConTasa(119000, 0.19), 19000);
    });
  });

  group('la función que usa la app', () {
    test('delega en la de tasa explícita con kIva', () {
      for (final monto in [0, 1000, 87654]) {
        expect(ivaIncluidoEn(monto), ivaIncluidoEnConTasa(monto, kIva));
      }
    });

    test('hoy kIva es 0, así que no hay IVA en ninguna parte', () {
      expect(hayIva, isFalse);
      expect(ivaIncluidoEn(100000), 0);
      expect(baseSinIva(100000), 100000);
    });
  });
}
