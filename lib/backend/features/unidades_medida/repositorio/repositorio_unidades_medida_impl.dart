import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import '../../../../core/resultado.dart';
import '../modelo/unidad_medida.dart';
import 'repositorio_unidades_medida.dart';
import '../../../share/dominio/sesion_actual.dart';
import '../../bitacora/modelo/entrada_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora.dart';
import '../../bitacora/repositorio/repositorio_bitacora_impl.dart';
import '../../../share/dominio/permiso.dart';

class RepositorioUnidadesMedidaImpl with FirmaDeSesion implements RepositorioUnidadesMedida {
  final AppDb _db;

  RepositorioUnidadesMedidaImpl(this._db, this.sesion);

  /// Quién firma lo que este repositorio escribe. La inyecta Riverpod por el
  /// constructor, no la busca en ningún registro global.
  @override
  final SesionActual? sesion;

  late final RepositorioBitacora _bitacora =
      RepositorioBitacoraImpl(_db, sesion);

  /// Deja el renglón de la bitácora. Se llama **dentro** de la transacción del
  /// cambio: si la escritura se revierte, el renglón se va con ella.
  Future<void> _anotar(
    AccionAuditada accion,
    int? id,
    String descripcion, {
    String? detalle,
  }) =>
      _bitacora.anotar(
        Anotacion(
          entidad: EntidadAuditada.unidadMedida,
          accion: accion,
          entidadId: id,
          descripcion: descripcion,
          detalle: detalle,
        ),
      );


  UnidadMedida _filaAModelo(TablaUnidadesMedidaData fila) {
    return UnidadMedida(
      id: fila.id,
      nombre: fila.nombre,
      abreviatura: fila.abreviatura,
      tipo: fila.tipo,
      descripcion: fila.descripcion,
      creadoEn: fila.creadoEn,
      actualizadoEn: fila.actualizadoEn,
    );
  }

  /// El recorte va aquí y no en el diálogo: normalizar es del repositorio
  /// (`REGLAS_BD.md` §2). Si lo hiciera la vista, la unidad creada desde otra
  /// pantalla entraría con espacios y el `UNIQUE` dejaría pasar « lt».
  TablaUnidadesMedidaCompanion _modeloACompanion(UnidadMedida unidad) {
    return TablaUnidadesMedidaCompanion(
      id: unidad.id != null ? Value(unidad.id!) : const Value.absent(),
      nombre: Value(unidad.nombre.trim()),
      abreviatura: Value(unidad.abreviatura.trim()),
      tipo: Value(unidad.tipo),
      descripcion: Value(unidad.descripcion?.trim()),
      actualizadoEn: Value(DateTime.now()),
    );
  }

  @override
  Future<List<UnidadMedida>> obtenerTodas() async {
    final filas = await _db.select(_db.tablaUnidadesMedida).get();
    return filas.map(_filaAModelo).toList();
  }

  @override
  Future<UnidadMedida?> obtenerPorId(int id) async {
    final fila = await (_db.select(
      _db.tablaUnidadesMedida,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return fila != null ? _filaAModelo(fila) : null;
  }

  @override
  Future<List<UnidadMedida>> buscarPorNombre(String consulta) async {
    final filas = await (_db.select(
      _db.tablaUnidadesMedida,
    )..where((t) => t.nombre.like('%$consulta%'))).get();
    return filas.map(_filaAModelo).toList();
  }

  @override
  Future<List<UnidadMedida>> obtenerPorTipo(String tipo) async {
    final filas = await (_db.select(
      _db.tablaUnidadesMedida,
    )..where((t) => t.tipo.equals(tipo))).get();
    return filas.map(_filaAModelo).toList();
  }

  /// Las dos unicidades de la tabla, comprobadas antes de escribir para poder
  /// decir **cuál** de las dos estorba. La garantía sigue siendo el `UNIQUE`;
  /// esto solo existe para que el diálogo señale el campo correcto.
  Future<Fallo?> _choque(UnidadMedida unidad, {int? excluir}) async {
    if (await existeNombre(unidad.nombre, excludirId: excluir)) {
      return const Fallo(
        MotivoFallo.nombreDuplicado,
        'Ya existe una unidad con ese nombre.',
      );
    }
    if (await existeAbreviatura(unidad.abreviatura, excludirId: excluir)) {
      return const Fallo(
        MotivoFallo.abreviaturaDuplicada,
        'Ya existe una unidad con esa abreviatura.',
      );
    }
    return null;
  }

  /// Lo que ni el `CHECK` ni el `UNIQUE` cubren: que los dos campos
  /// obligatorios traigan algo.
  static Fallo? _vacios(UnidadMedida unidad) {
    if (unidad.nombre.trim().isEmpty) {
      return const Fallo(
        MotivoFallo.validacion,
        'El nombre no puede estar vacío.',
      );
    }
    if (unidad.abreviatura.trim().isEmpty) {
      return const Fallo(
        MotivoFallo.validacion,
        'La abreviatura no puede estar vacía.',
      );
    }
    return null;
  }

  @override
  Future<Resultado> crear(UnidadMedida unidad) => intentar(() async {
        exigir(Permiso.configuracionEditar);
        final invalido = _vacios(unidad) ?? await _choque(unidad);
        if (invalido != null) return invalido;

        await _db.transaction(() async {
          final id = await _db
              .into(_db.tablaUnidadesMedida)
              .insert(_modeloACompanion(unidad));
          await _anotar(AccionAuditada.creo, id, unidad.nombre.trim());
        });
        return const Exito();
      });

  @override
  Future<Resultado> actualizar(UnidadMedida unidad) => intentar(() async {
        exigir(Permiso.configuracionEditar);
        final id = unidad.id;
        if (id == null) {
          return const Fallo(
            MotivoFallo.validacion,
            'La unidad todavía no existe: no se puede actualizar.',
          );
        }
        final invalido =
            _vacios(unidad) ?? await _choque(unidad, excluir: id);
        if (invalido != null) return invalido;

        await _db.transaction(() async {
          final tocadas = await (_db.update(_db.tablaUnidadesMedida)
                ..where((t) => t.id.equals(id)))
              .write(_modeloACompanion(unidad));
          if (tocadas == 0) throw Exception('La unidad ya no existe.');
          await _anotar(AccionAuditada.modifico, id, unidad.nombre.trim());
        });
        return const Exito();
      });

  @override
  Future<Resultado> eliminar(int id) => intentar(() async {
        exigir(Permiso.configuracionEditar);
        await _db.transaction(() async {
          final antes = await obtenerPorId(id);
          final eliminadas = await (_db.delete(_db.tablaUnidadesMedida)
                ..where((t) => t.id.equals(id)))
              .go();
          if (eliminadas == 0) throw Exception('La unidad ya no existe.');
          await _anotar(
            AccionAuditada.elimino,
            id,
            antes?.nombre ?? 'Unidad #$id',
          );
        });
        return const Exito();
      });

  @override
  Future<bool> existeNombre(String nombre, {int? excludirId}) async {
    final query = _db.select(_db.tablaUnidadesMedida)
      ..where((t) => t.nombre.lower().equals(nombre.toLowerCase()));
    if (excludirId != null) {
      query.where((t) => t.id.equals(excludirId).not());
    }
    return await query.getSingleOrNull() != null;
  }

  @override
  Future<bool> existeAbreviatura(String abreviatura, {int? excludirId}) async {
    final query = _db.select(_db.tablaUnidadesMedida)
      ..where((t) => t.abreviatura.lower().equals(abreviatura.toLowerCase()));
    if (excludirId != null) {
      query.where((t) => t.id.equals(excludirId).not());
    }
    return await query.getSingleOrNull() != null;
  }
}
