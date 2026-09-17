import 'package:drift/drift.dart';

import '../../../../core/resultado.dart';
import '../../../share/database/app_db.dart';
import '../../../share/dominio/permiso.dart';
import '../../../share/dominio/sesion_actual.dart';
import '../../bitacora/modelo/entrada_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora_impl.dart';
import '../modelo/marca_moto.dart';
import 'repositorio_marcas_moto.dart';

class RepositorioMarcasMotoImpl
    with FirmaDeSesion
    implements RepositorioMarcasMoto {
  RepositorioMarcasMotoImpl(this._db, this.sesion);

  final AppDb _db;

  /// Quién firma lo que este repositorio escribe. La inyecta Riverpod por el
  /// constructor, no la busca en ningún registro global.
  @override
  final SesionActual? sesion;

  late final RepositorioBitacora _bitacora =
      RepositorioBitacoraImpl(_db, sesion);

  Future<void> _anotar(
    AccionAuditada accion,
    EntidadAuditada entidad,
    int? id,
    String descripcion, {
    String? detalle,
  }) =>
      _bitacora.anotar(
        Anotacion(
          entidad: entidad,
          accion: accion,
          entidadId: id,
          descripcion: descripcion,
          detalle: detalle,
        ),
      );

  /// Cómo entra un nombre de marca o modelo a la base.
  ///
  /// Sin esto «yamaha», «Yamaha» y « YAMAHA » serían tres marcas: el `UNIQUE`
  /// de SQLite compara byte a byte. Normalizar es del repositorio
  /// (`REGLAS_BD.md` §2), no de cada pantalla que da de alta una.
  static String _normalizar(String valor) {
    final limpio = valor.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (limpio.isEmpty) return limpio;
    return limpio[0].toUpperCase() + limpio.substring(1);
  }

  // ── Marcas ────────────────────────────────────────────────────────────────

  /// El conteo de modelos sale de un `COUNT` correlacionado y no de recorrer
  /// la lista en Dart (§5). `readsFrom` incluye las dos tablas: sin
  /// `modelos_moto`, agregar un modelo no volvería a emitir y el contador se
  /// quedaría viejo.
  Stream<List<MarcaMoto>> _marcas({required bool soloActivas}) => _db
      .customSelect(
        '''
        SELECT
          ma.id, ma.nombre, ma.activo,
          (SELECT COUNT(*) FROM modelos_moto md WHERE md.marca_id = ma.id)
            AS modelos
        FROM marcas_moto ma
        ${soloActivas ? 'WHERE ma.activo = 1' : ''}
        ORDER BY ma.nombre
        ''',
        readsFrom: {_db.tablaMarcaMoto, _db.tablaModeloMoto},
      )
      .watch()
      .map(
        (filas) => filas
            .map(
              (f) => MarcaMoto(
                id: f.read<int>('id'),
                nombre: f.read<String>('nombre'),
                activo: f.read<bool>('activo'),
                modelos: f.read<int>('modelos'),
              ),
            )
            .toList(growable: false),
      );

  @override
  Stream<List<MarcaMoto>> observarMarcas({bool soloActivas = false}) =>
      _marcas(soloActivas: soloActivas);

  @override
  Future<List<MarcaMoto>> obtenerMarcas({bool soloActivas = true}) =>
      _marcas(soloActivas: soloActivas).first;

  @override
  Future<Resultado> crearMarca(String nombre) => intentar(() async {
        exigir(Permiso.configuracionEditar);
        final limpio = _normalizar(nombre);
        if (limpio.isEmpty) {
          return const Fallo(
            MotivoFallo.validacion,
            'El nombre de la marca no puede estar vacío.',
          );
        }
        if (await _existeMarca(limpio)) {
          return const Fallo(
            MotivoFallo.nombreDuplicado,
            'Ya existe una marca con ese nombre.',
          );
        }
        await _db.transaction(() async {
          final id = await _db
              .into(_db.tablaMarcaMoto)
              .insert(TablaMarcaMotoCompanion.insert(nombre: limpio));
          await _anotar(
            AccionAuditada.creo,
            EntidadAuditada.marcaMoto,
            id,
            limpio,
          );
        });
        return const Exito();
      });

  @override
  Future<Resultado> renombrarMarca(int id, String nombre) =>
      intentar(() async {
        exigir(Permiso.configuracionEditar);
        final limpio = _normalizar(nombre);
        if (limpio.isEmpty) {
          return const Fallo(
            MotivoFallo.validacion,
            'El nombre de la marca no puede estar vacío.',
          );
        }
        if (await _existeMarca(limpio, ignorarId: id)) {
          return const Fallo(
            MotivoFallo.nombreDuplicado,
            'Ya existe una marca con ese nombre.',
          );
        }
        await _db.transaction(() async {
          final tocadas =
              await (_db.update(_db.tablaMarcaMoto)..where((t) => t.id.equals(id)))
                  .write(
            TablaMarcaMotoCompanion(
              nombre: Value(limpio),
              actualizadoEn: Value(DateTime.now()),
            ),
          );
          if (tocadas == 0) throw Exception('La marca ya no existe.');
          await _anotar(
            AccionAuditada.modifico,
            EntidadAuditada.marcaMoto,
            id,
            limpio,
          );
        });
        return const Exito();
      });

  @override
  Future<Resultado> cambiarEstadoMarca(int id, {required bool activa}) =>
      intentar(() async {
        exigir(Permiso.configuracionEditar);
        await _db.transaction(() async {
          final antes =
              await (_db.select(_db.tablaMarcaMoto)..where((t) => t.id.equals(id)))
                  .getSingleOrNull();
          if (antes == null) throw Exception('La marca ya no existe.');

          await (_db.update(_db.tablaMarcaMoto)..where((t) => t.id.equals(id)))
              .write(
            TablaMarcaMotoCompanion(
              activo: Value(activa),
              actualizadoEn: Value(DateTime.now()),
            ),
          );
          await _anotar(
            AccionAuditada.modifico,
            EntidadAuditada.marcaMoto,
            id,
            antes.nombre,
            detalle: activa ? 'Reactivada' : 'Dada de baja',
          );
        });
        return const Exito();
      });

  Future<bool> _existeMarca(String nombre, {int? ignorarId}) async {
    final consulta = _db.select(_db.tablaMarcaMoto)
      ..where((t) => t.nombre.lower().equals(nombre.toLowerCase()));
    if (ignorarId != null) consulta.where((t) => t.id.isNotValue(ignorarId));
    return await consulta.getSingleOrNull() != null;
  }

  // ── Modelos ───────────────────────────────────────────────────────────────

  JoinedSelectStatement<HasResultSet, dynamic> _consultaModelos({
    int? marcaId,
    required bool soloActivos,
  }) {
    final consulta = _db.select(_db.tablaModeloMoto).join([
      innerJoin(
        _db.tablaMarcaMoto,
        _db.tablaMarcaMoto.id.equalsExp(_db.tablaModeloMoto.marcaId),
      ),
    ])
      ..orderBy([
        OrderingTerm.asc(_db.tablaMarcaMoto.nombre),
        OrderingTerm.asc(_db.tablaModeloMoto.nombre),
      ]);

    if (marcaId != null) {
      consulta.where(_db.tablaModeloMoto.marcaId.equals(marcaId));
    }
    if (soloActivos) {
      // También la marca: un modelo activo de una marca dada de baja no debe
      // aparecer, o el selector ofrecería algo que el taller ya no atiende.
      consulta.where(
        _db.tablaModeloMoto.activo.equals(true) &
            _db.tablaMarcaMoto.activo.equals(true),
      );
    }
    return consulta;
  }

  ModeloMoto _aModelo(TypedResult row) {
    final m = row.readTable(_db.tablaModeloMoto);
    return ModeloMoto(
      id: m.id,
      marcaId: m.marcaId,
      nombre: m.nombre,
      cilindraje: m.cilindraje,
      activo: m.activo,
      marca: row.readTable(_db.tablaMarcaMoto).nombre,
    );
  }

  @override
  Stream<List<ModeloMoto>> observarModelos({
    int? marcaId,
    bool soloActivos = false,
  }) =>
      _consultaModelos(marcaId: marcaId, soloActivos: soloActivos)
          .watch()
          .map((filas) => filas.map(_aModelo).toList(growable: false));

  @override
  Future<List<ModeloMoto>> obtenerModelos({
    int? marcaId,
    bool soloActivos = true,
  }) async {
    final filas =
        await _consultaModelos(marcaId: marcaId, soloActivos: soloActivos)
            .get();
    return filas.map(_aModelo).toList(growable: false);
  }

  @override
  Future<Resultado> crearModelo({
    required int marcaId,
    required String nombre,
    int? cilindraje,
  }) =>
      intentar(() async {
        exigir(Permiso.configuracionEditar);
        final limpio = _normalizar(nombre);
        if (limpio.isEmpty) {
          return const Fallo(
            MotivoFallo.validacion,
            'El nombre del modelo no puede estar vacío.',
          );
        }
        if (await _existeModelo(marcaId, limpio)) {
          return const Fallo(
            MotivoFallo.nombreDuplicado,
            'Esa marca ya tiene un modelo con ese nombre.',
          );
        }
        await _db.transaction(() async {
          final id = await _db.into(_db.tablaModeloMoto).insert(
                TablaModeloMotoCompanion.insert(
                  marcaId: marcaId,
                  nombre: limpio,
                  cilindraje: Value(cilindraje),
                ),
              );
          await _anotar(
            AccionAuditada.creo,
            EntidadAuditada.modeloMoto,
            id,
            limpio,
          );
        });
        return const Exito();
      });

  @override
  Future<Resultado> actualizarModelo({
    required int id,
    required String nombre,
    int? cilindraje,
  }) =>
      intentar(() async {
        exigir(Permiso.configuracionEditar);
        final limpio = _normalizar(nombre);
        if (limpio.isEmpty) {
          return const Fallo(
            MotivoFallo.validacion,
            'El nombre del modelo no puede estar vacío.',
          );
        }
        final actual =
            await (_db.select(_db.tablaModeloMoto)..where((t) => t.id.equals(id)))
                .getSingleOrNull();
        if (actual == null) {
          return const Fallo(
            MotivoFallo.validacion,
            'El modelo ya no existe.',
          );
        }
        if (await _existeModelo(actual.marcaId, limpio, ignorarId: id)) {
          return const Fallo(
            MotivoFallo.nombreDuplicado,
            'Esa marca ya tiene un modelo con ese nombre.',
          );
        }
        await _db.transaction(() async {
          await (_db.update(_db.tablaModeloMoto)..where((t) => t.id.equals(id)))
              .write(
            TablaModeloMotoCompanion(
              nombre: Value(limpio),
              cilindraje: Value(cilindraje),
              actualizadoEn: Value(DateTime.now()),
            ),
          );
          await _anotar(
            AccionAuditada.modifico,
            EntidadAuditada.modeloMoto,
            id,
            limpio,
          );
        });
        return const Exito();
      });

  @override
  Future<Resultado> cambiarEstadoModelo(int id, {required bool activo}) =>
      intentar(() async {
        exigir(Permiso.configuracionEditar);
        await _db.transaction(() async {
          final antes =
              await (_db.select(_db.tablaModeloMoto)..where((t) => t.id.equals(id)))
                  .getSingleOrNull();
          if (antes == null) throw Exception('El modelo ya no existe.');

          await (_db.update(_db.tablaModeloMoto)..where((t) => t.id.equals(id)))
              .write(
            TablaModeloMotoCompanion(
              activo: Value(activo),
              actualizadoEn: Value(DateTime.now()),
            ),
          );
          await _anotar(
            AccionAuditada.modifico,
            EntidadAuditada.modeloMoto,
            id,
            antes.nombre,
            detalle: activo ? 'Reactivado' : 'Dado de baja',
          );
        });
        return const Exito();
      });

  Future<bool> _existeModelo(
    int marcaId,
    String nombre, {
    int? ignorarId,
  }) async {
    final consulta = _db.select(_db.tablaModeloMoto)
      ..where(
        (t) =>
            t.marcaId.equals(marcaId) &
            t.nombre.lower().equals(nombre.toLowerCase()),
      );
    if (ignorarId != null) consulta.where((t) => t.id.isNotValue(ignorarId));
    return await consulta.getSingleOrNull() != null;
  }

  // ── Alta al vuelo ─────────────────────────────────────────────────────────

  @override
  Future<int> asegurarMarca(String nombre) async {
    final limpio = _normalizar(nombre);
    if (limpio.isEmpty) {
      throw Exception('La moto necesita una marca.');
    }

    final existente = await (_db.select(_db.tablaMarcaMoto)
          ..where((t) => t.nombre.lower().equals(limpio.toLowerCase()))
          ..limit(1))
        .getSingleOrNull();
    if (existente != null) return existente.id;

    // Dar de alta una marca desde el formulario de una moto no pide
    // `configuracionEditar`: quien puede registrar la moto de un cliente tiene
    // que poder terminar de registrarla. La pantalla de Configuración, que es
    // donde se renombra y se da de baja, sí lo exige.
    exigir(Permiso.clientesEditar);
    return _db.transaction(() async {
      final id = await _db
          .into(_db.tablaMarcaMoto)
          .insert(TablaMarcaMotoCompanion.insert(nombre: limpio));
      await _anotar(
        AccionAuditada.creo,
        EntidadAuditada.marcaMoto,
        id,
        limpio,
        detalle: 'Creada al registrar una moto',
      );
      return id;
    });
  }

  @override
  Future<int?> asegurarModelo({
    required int marcaId,
    required String? nombre,
    int? cilindraje,
  }) async {
    final limpio = _normalizar(nombre ?? '');
    if (limpio.isEmpty) return null;

    final existente = await (_db.select(_db.tablaModeloMoto)
          ..where(
            (t) =>
                t.marcaId.equals(marcaId) &
                t.nombre.lower().equals(limpio.toLowerCase()),
          )
          ..limit(1))
        .getSingleOrNull();
    if (existente != null) {
      // El cilindraje del modelo se completa la primera vez que alguien lo
      // sabe, pero no se pisa: si ya está, el dato del catálogo manda sobre lo
      // que teclee quien registra una moto suelta.
      if (existente.cilindraje == null && cilindraje != null) {
        await (_db.update(_db.tablaModeloMoto)
              ..where((t) => t.id.equals(existente.id)))
            .write(
          TablaModeloMotoCompanion(
            cilindraje: Value(cilindraje),
            actualizadoEn: Value(DateTime.now()),
          ),
        );
      }
      return existente.id;
    }

    exigir(Permiso.clientesEditar);
    return _db.transaction(() async {
      final id = await _db.into(_db.tablaModeloMoto).insert(
            TablaModeloMotoCompanion.insert(
              marcaId: marcaId,
              nombre: limpio,
              cilindraje: Value(cilindraje),
            ),
          );
      await _anotar(
        AccionAuditada.creo,
        EntidadAuditada.modeloMoto,
        id,
        limpio,
        detalle: 'Creado al registrar una moto',
      );
      return id;
    });
  }
}
