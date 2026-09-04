// El encabezado impreso —y el papel en que sale— tienen que decir lo que dice
// Configuración **hoy**.
//
// Esto existe por un bug real: `negocioImpresoProvider` era un `FutureProvider`
// cuya única dependencia era el provider del repositorio, que nunca cambia.
// Riverpod cacheaba el resultado, así que cambiar el nombre del taller y
// emitir una factura nueva seguía imprimiendo el nombre viejo hasta reiniciar
// la app. Un test de widget no lo habría visto: hay que escribir y volver a
// leer.
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/configuracion/modelo/clave_configuracion.dart';
import 'package:inventario_k1/backend/features/configuracion/repositorio/repositorio_configuracion_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/permiso.dart';
import 'package:inventario_k1/frontend/features/documentos/provider/documentos_providers.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/sesion_de_prueba.dart';

void main() {
  late AppDb db;
  late RepositorioConfiguracionImpl repositorio;

  setUp(() async {
    db = baseEnMemoria();
    repositorio = RepositorioConfiguracionImpl(db, await sesionDePrueba(db));
  });

  tearDown(() async => db.close());

  test('imprimir no exige entrar a Configuración', () async {
    // El encabezado del PDF lo lee un cajero cada vez que cobra, y un cajero
    // no tiene `CONFIGURACION_VER`. Si esto pidiera permiso, cobrar e imprimir
    // reventaría en el mostrador.
    final cajero = RepositorioConfiguracionImpl(
      db,
      await sesionDePrueba(db, permisos: {Permiso.posVender}, usuario: 'caja'),
    );

    expect((await leerAjustesImpresion(cajero)).negocio.nombre,
        ClaveConfiguracion.nombreNegocio.porDefecto);
  });

  test('sin configurar nada usa los valores por defecto', () async {
    final negocio = (await leerAjustesImpresion(repositorio)).negocio;
    expect(negocio.nombre, ClaveConfiguracion.nombreNegocio.porDefecto);
  });

  test('cambiar el nombre se ve en la impresión siguiente', () async {
    await repositorio.guardar(
        ClaveConfiguracion.nombreNegocio, 'Taller K1 Motos');
    expect((await leerAjustesImpresion(repositorio)).negocio.nombre, 'Taller K1 Motos');

    // El segundo cambio es el que importa: con la caché, este devolvía el
    // primero.
    await repositorio.guardar(
        ClaveConfiguracion.nombreNegocio, 'Motorepuestos del Valle');
    expect((await leerAjustesImpresion(repositorio)).negocio.nombre,
        'Motorepuestos del Valle');
  });

  test('el resto del encabezado también se relee', () async {
    await repositorio.guardar(ClaveConfiguracion.nit, '901.555.222-8');
    await repositorio.guardar(ClaveConfiguracion.direccion, 'Cra. 8 #23-45');
    await repositorio.guardar(ClaveConfiguracion.ciudad, 'Cali');
    await repositorio.guardar(ClaveConfiguracion.telefono, '602 555 7788');

    final negocio = (await leerAjustesImpresion(repositorio)).negocio;
    expect(negocio.lineaUbicacion, 'Cra. 8 #23-45 · Cali');
    expect(negocio.lineaContacto, 'NIT 901.555.222-8 · Tel. 602 555 7788');

    await repositorio.guardar(ClaveConfiguracion.ciudad, 'Palmira');
    expect((await leerAjustesImpresion(repositorio)).negocio.lineaUbicacion,
        'Cra. 8 #23-45 · Palmira');
  });
}
