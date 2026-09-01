import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_k1/backend/features/especializacion/repositorio/repositorio_especializacion_impl.dart';
import 'package:inventario_k1/backend/features/servicios/repositorio/repositorio_servicios_impl.dart';
import 'package:inventario_k1/backend/features/unidades_medida/modelo/unidad_medida.dart';
import 'package:inventario_k1/backend/features/unidades_medida/repositorio/repositorio_unidades_medida_impl.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/permiso.dart';
import 'package:inventario_k1/backend/share/dominio/sesion_actual.dart';
import 'package:inventario_k1/core/resultado.dart';

import 'soporte/base_en_memoria.dart';
import 'soporte/sesion_de_prueba.dart';

/// Los tres catálogos de Configuración devuelven `Resultado` y no `String?`.
///
/// Lo que se prueba no es que «no falle», sino que el **motivo** llegue
/// distinguible: mientras devolvían un texto, la vista tenía que buscar la
/// palabra `UNIQUE` dentro del `toString()` de una excepción para adivinar que
/// el nombre estaba repetido, y no había forma de separar eso de un fallo real
/// de SQLite ni de un permiso que falta.
void main() {
  late AppDb db;
  late SesionActual sesion;

  UnidadMedida unidad(String nombre, String abreviatura) => UnidadMedida(
        nombre: nombre,
        abreviatura: abreviatura,
        tipo: 'unidad',
        creadoEn: DateTime.now(),
        actualizadoEn: DateTime.now(),
      );

  setUp(() async {
    db = baseEnMemoria();
    sesion = await sesionDePrueba(db);
  });

  tearDown(() => db.close());

  group('servicios', () {
    test('el nombre repetido vuelve como nombreDuplicado, no como texto',
        () async {
      final repo = RepositorioServiciosImpl(db, sesion);
      expect(await repo.agregar(nombre: 'Cambio de aceite'), isA<Exito>());

      final segundo = await repo.agregar(nombre: 'Cambio de aceite');

      expect(segundo, isA<Fallo>());
      expect((segundo as Fallo).motivo, MotivoFallo.nombreDuplicado);
    });

    test('choca igual ignorando mayúsculas y espacios de sobra', () async {
      final repo = RepositorioServiciosImpl(db, sesion);
      await repo.agregar(nombre: 'Sincronización');

      final segundo = await repo.agregar(nombre: '  SINCRONIZACIÓN  ');

      expect((segundo as Fallo).motivo, MotivoFallo.nombreDuplicado);
    });

    test('editar un servicio con su propio nombre no choca consigo mismo',
        () async {
      final repo = RepositorioServiciosImpl(db, sesion);
      await repo.agregar(nombre: 'Frenos');
      final id = (await repo.obtenerTodos()).single.id;

      final resultado = await repo.actualizar(
        id: id,
        nombre: 'Frenos',
        descripcion: 'Ahora con descripción',
        activo: true,
      );

      expect(resultado, isA<Exito>());
    });

    test('sin permiso el motivo es validacion, no persistencia', () async {
      // Un permiso que falta no es un fallo de la base: la base ni se tocó.
      // La vista necesita poder distinguirlo para no decir «error al guardar».
      final mirona = await sesionDePrueba(
        db,
        permisos: {Permiso.configuracionVer},
        usuario: 'mirona',
      );
      final repo = RepositorioServiciosImpl(db, mirona);

      final resultado = await repo.agregar(nombre: 'Lavado');

      expect(resultado, isA<Fallo>());
      expect((resultado as Fallo).motivo, MotivoFallo.validacion);
      expect(await repo.obtenerTodos(), isEmpty);
    });

    test('un nombre en blanco se rechaza como validacion', () async {
      final repo = RepositorioServiciosImpl(db, sesion);

      final resultado = await repo.agregar(nombre: '   ');

      expect((resultado as Fallo).motivo, MotivoFallo.validacion);
    });

    test('eliminar algo que ya no está no revienta: devuelve Fallo', () async {
      final repo = RepositorioServiciosImpl(db, sesion);

      final resultado = await repo.eliminar(404);

      expect(resultado, isA<Fallo>());
      expect((resultado as Fallo).motivo, MotivoFallo.persistencia);
    });
  });

  group('especializaciones', () {
    test('el nombre repetido vuelve como nombreDuplicado', () async {
      final repo = RepositorioEspecializacionImpl(db, sesion);
      expect(await repo.agregar(nombre: 'Motor'), isA<Exito>());

      final segundo = await repo.agregar(nombre: 'motor');

      expect((segundo as Fallo).motivo, MotivoFallo.nombreDuplicado);
    });

    test('sin permiso no escribe y el motivo es validacion', () async {
      final mirona = await sesionDePrueba(
        db,
        permisos: const {},
        usuario: 'mirona',
      );
      final repo = RepositorioEspecializacionImpl(db, mirona);

      final resultado = await repo.agregar(nombre: 'Eléctrico');

      expect((resultado as Fallo).motivo, MotivoFallo.validacion);
      expect(await repo.obtenerTodas(), isEmpty);
    });
  });

  group('unidades de medida', () {
    test('el nombre y la abreviatura repetidos NO son el mismo motivo',
        () async {
      // Es la razón de que exista `MotivoFallo.abreviaturaDuplicada`: son dos
      // `UNIQUE` distintos sobre la misma fila, y el formulario tiene que
      // poder decir cuál de los dos campos estorba.
      final repo = RepositorioUnidadesMedidaImpl(db, sesion);
      expect(await repo.crear(unidad('Litro', 'lt')), isA<Exito>());

      final porNombre = await repo.crear(unidad('Litro', 'l'));
      final porAbreviatura = await repo.crear(unidad('Litros', 'lt'));

      expect((porNombre as Fallo).motivo, MotivoFallo.nombreDuplicado);
      expect(
        (porAbreviatura as Fallo).motivo,
        MotivoFallo.abreviaturaDuplicada,
      );
    });

    test('el nombre entra recortado, no con los espacios que se tecleen',
        () async {
      // Normalizar es del repositorio (`REGLAS_BD.md` §2). Si lo hiciera la
      // vista, la unidad creada desde otra pantalla entraría con espacios y el
      // `UNIQUE` dejaría pasar « lt» al lado de «lt».
      final repo = RepositorioUnidadesMedidaImpl(db, sesion);

      await repo.crear(unidad('  Kilogramo  ', '  kg  '));

      final guardada = (await repo.obtenerTodas()).single;
      expect(guardada.nombre, 'Kilogramo');
      expect(guardada.abreviatura, 'kg');
    });

    test('sin permiso no escribe y el motivo es validacion', () async {
      final mirona = await sesionDePrueba(
        db,
        permisos: const {},
        usuario: 'mirona',
      );
      final repo = RepositorioUnidadesMedidaImpl(db, mirona);

      final resultado = await repo.crear(unidad('Metro', 'm'));

      expect((resultado as Fallo).motivo, MotivoFallo.validacion);
      expect(await repo.obtenerTodas(), isEmpty);
    });
  });
}
