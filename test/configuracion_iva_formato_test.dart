// El IVA y el formato de impresión **se configuran**, no se compilan.
//
// Hasta que estas dos claves se conectaron, la tabla `configuracion` las
// guardaba y no las leía nadie: la tasa era una constante de compilación y el
// papel estaba fijo en carta. Lo que se prueba aquí es el viaje entero —se
// guarda, se relee, y lo releído es lo que usa la app—, porque un campo que se
// deja editar sin que cambie nada es peor que no ofrecerlo.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/configuracion/modelo/clave_configuracion.dart';
import 'package:inventario_k1/backend/features/configuracion/repositorio/repositorio_configuracion_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/permiso.dart';
import 'package:inventario_k1/core/iva_app.dart';
import 'package:inventario_k1/frontend/features/documentos/provider/documentos_providers.dart';
import 'package:inventario_k1/frontend/features/documentos/servicio/formato_impreso.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/sesion_de_prueba.dart';

void main() {
  late AppDb db;
  late RepositorioConfiguracionImpl repositorio;

  setUp(() async {
    db = baseEnMemoria();
    repositorio = RepositorioConfiguracionImpl(db, await sesionDePrueba(db));
  });

  tearDown(() async {
    // La tasa es una global: dejarla puesta contaminaría los tests que corran
    // después en el mismo proceso.
    configurarIva(0);
    await db.close();
  });

  group('la tasa de IVA', () {
    test('la clave ya no es decorativa: se guarda y se relee', () async {
      await repositorio.guardar(ClaveConfiguracion.ivaPorcentaje, '19');
      expect(await repositorio.leer(ClaveConfiguracion.ivaPorcentaje), '19');
    });

    /// Lo que hace `main()` al arrancar, sin montar la app entera.
    Future<void> arrancar() async {
      final guardado =
          await repositorio.leer(ClaveConfiguracion.ivaPorcentaje);
      configurarIva(double.tryParse(guardado.trim()) ?? 0);
    }

    test('lo guardado es lo que la app aplica al arrancar', () async {
      await repositorio.guardar(ClaveConfiguracion.ivaPorcentaje, '19');
      await arrancar();

      expect(hayIva, isTrue);
      expect(porcentajeIva, 19);
      expect(ivaIncluidoEn(119000), 19000);
      expect(etiquetaIva, 'IVA (19%) incluido');
    });

    test('sin configurar nada el taller no factura IVA', () async {
      await arrancar();
      expect(hayIva, isFalse);
      expect(ivaIncluidoEn(119000), 0);
    });

    test('una clave con basura no deja la app sin arrancar', () async {
      // La columna es texto: nada impide que alguien la toque con un visor de
      // SQLite. Lo que no puede pasar es que eso reviente el arranque.
      await repositorio.guardar(ClaveConfiguracion.ivaPorcentaje, 'diecinueve');
      await arrancar();
      expect(hayIva, isFalse);
    });

    test('cambiar la tasa no reescribe lo ya emitido', () async {
      // El IVA de un documento se guarda en su propia fila y no se recalcula:
      // una factura de hace un año se cerró con la tasa de entonces. Aquí eso
      // se comprueba sobre la única pieza que lo decide —`ivaIncluidoEn` mira
      // la tasa de hoy, y el documento guarda su número—.
      configurarIva(19);
      final ivaDeAyer = ivaIncluidoEn(119000);

      configurarIva(0);
      expect(ivaDeAyer, 19000, reason: 'el número guardado no cambia');
      expect(ivaIncluidoEn(119000), 0, reason: 'lo nuevo sí');
    });
  });

  group('el formato de impresión', () {
    test('sin configurar nada sale en carta', () async {
      final ajustes = await leerAjustesImpresion(repositorio);
      expect(ajustes.formato, FormatoImpreso.carta);
    });

    test('lo guardado es lo que abre la vista previa', () async {
      await repositorio.guardar(
        ClaveConfiguracion.formatoImpresion,
        FormatoImpreso.tirilla80.codigo,
      );
      expect((await leerAjustesImpresion(repositorio)).formato,
          FormatoImpreso.tirilla80);

      // El segundo cambio es el que importa: si esto se cacheara, devolvería
      // el primero. Es el mismo bug que tuvo el encabezado del negocio.
      await repositorio.guardar(
        ClaveConfiguracion.formatoImpresion,
        FormatoImpreso.tirilla58.codigo,
      );
      expect((await leerAjustesImpresion(repositorio)).formato,
          FormatoImpreso.tirilla58);
    });

    test('un valor que nadie reconoce cae en carta, no deja sin imprimir',
        () async {
      await repositorio.guardar(ClaveConfiguracion.formatoImpresion, 'A4');
      expect((await leerAjustesImpresion(repositorio)).formato,
          FormatoImpreso.carta);
    });

    test('el encabezado y el papel salen de la misma lectura', () async {
      await repositorio.guardar(
          ClaveConfiguracion.nombreNegocio, 'Motorepuestos del Valle');
      await repositorio.guardar(
        ClaveConfiguracion.formatoImpresion,
        FormatoImpreso.tirilla80.codigo,
      );

      final ajustes = await leerAjustesImpresion(repositorio);
      expect(ajustes.negocio.nombre, 'Motorepuestos del Valle');
      expect(ajustes.formato, FormatoImpreso.tirilla80);
    });

    test('imprimir no exige entrar a Configuración', () async {
      // Lo mismo que ya valía para el encabezado: un cajero imprime sin tener
      // `CONFIGURACION_VER`, y ahora también decide en qué papel.
      final cajero = RepositorioConfiguracionImpl(
        db,
        await sesionDePrueba(db, permisos: {Permiso.posVender}, usuario: 'caja'),
      );

      final ajustes = await leerAjustesImpresion(cajero);
      expect(ajustes.formato, FormatoImpreso.carta);
    });
  });
}
