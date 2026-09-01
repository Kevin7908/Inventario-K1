import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../../../share/dominio/permiso.dart';
import '../../../share/dominio/sesion_actual.dart';
import '../mapper/bitacora_mapper.dart';
import '../modelo/entrada_bitacora.dart';
import 'repositorio_bitacora.dart';

class RepositorioBitacoraImpl with FirmaDeSesion implements RepositorioBitacora {
  RepositorioBitacoraImpl(this._db, this.sesion);

  final AppDb _db;

  /// Quién firma cada renglón. La inyecta Riverpod por el constructor.
  @override
  final SesionActual? sesion;

  $TablaBitacoraTable get _tabla => _db.tablaBitacora;
  $TablaUsuarioTable get _usuarios => _db.tablaUsuario;
  $TablaPersonaTable get _personas => _db.tablaPersona;

  /// **Sin compuerta, a propósito.** Anotar no es una acción del usuario: es
  /// el rastro que deja la que sí lo es, y ya viene de un método que comprobó
  /// su propio permiso. Exigir uno aquí dejaría a un cajero borrando un
  /// producto sin que quede constancia, que es exactamente lo contrario de
  /// para lo que existe esta tabla.
  @override
  Future<void> anotar(Anotacion anotacion) async {
    await _db.into(_tabla).insert(
          TablaBitacoraCompanion.insert(
            usuarioId: autorId,
            entidad: anotacion.entidad.codigo,
            entidadId: Value(anotacion.entidadId),
            accion: anotacion.accion.codigo,
            descripcion: anotacion.descripcion,
            detalle: Value(anotacion.detalle),
          ),
        );
  }

  @override
  Stream<PaginaBitacora> observarPagina({
    required FiltroBitacora filtro,
    required int pagina,
    required int tamano,
  }) {
    // Leer la bitácora es un permiso aparte: dice quién movió el stock y quién
    // borró qué, y eso no lo mira cualquiera. Esconder el ítem del sidebar es
    // orden; esta línea es el control (`CLAUDE.md` §7 bis).
    exigir(Permiso.bitacoraVer);

    final condicion = _condicion(filtro);

    final consultaPagina = _conAutor()
      ..where(condicion)
      ..orderBy([OrderingTerm.desc(_tabla.creadoEn), OrderingTerm.desc(_tabla.id)])
      ..limit(tamano, offset: pagina * tamano);

    // El total va en su propia consulta: el `LIMIT` no debe afectarlo.
    final total = _tabla.id.count();
    final consultaTotal = _db.select(_tabla).join([
      innerJoin(_usuarios, _usuarios.id.equalsExp(_tabla.usuarioId)),
      innerJoin(_personas, _personas.id.equalsExp(_usuarios.personaId)),
    ])
      ..addColumns([total])
      ..where(condicion);

    return consultaPagina.watch().asyncMap((filas) async {
      final fila = await consultaTotal.getSingleOrNull();
      return PaginaBitacora(
        items: filas.map((f) => BitacoraMapper.filaAModelo(f, _db)).toList(),
        total: fila?.read(total) ?? 0,
      );
    });
  }

  @override
  Future<List<EntradaBitacora>> historialDe(
    EntidadAuditada entidad,
    int entidadId, {
    int limite = 20,
  }) async {
    exigir(Permiso.bitacoraVer);

    final filas = await (_conAutor()
          ..where(_tabla.entidad.equals(entidad.codigo) &
              _tabla.entidadId.equals(entidadId))
          // El `id` desempata: dos cambios dentro del mismo milisegundo
          // —que es lo normal en una edición seguida de un alta— quedarían
          // en un orden arbitrario con solo la fecha.
          ..orderBy([
            OrderingTerm.desc(_tabla.creadoEn),
            OrderingTerm.desc(_tabla.id),
          ])
          ..limit(limite))
        .get();

    return filas.map((f) => BitacoraMapper.filaAModelo(f, _db)).toList();
  }

  @override
  Future<int> cuantasPodaria({required int meses}) async {
    exigir(Permiso.bitacoraVer);

    final conteo = _tabla.id.count();
    final fila = await (_db.selectOnly(_tabla)
          ..addColumns([conteo])
          ..where(_tabla.creadoEn.isSmallerThanValue(_corte(meses))))
        .getSingleOrNull();

    return fila?.read(conteo) ?? 0;
  }

  @override
  Future<int> podar({required int meses}) async {
    // Recortar la bitácora no es leerla: es el gesto que se usaría para tapar
    // lo demás, así que pide el permiso de administrar cuentas y no el de ver.
    exigir(Permiso.usuariosAdministrar);

    final corte = _corte(meses);

    return _db.transaction(() async {
      final cuantas = await (_db.delete(_tabla)
            ..where((t) => t.creadoEn.isSmallerThanValue(corte)))
          .go();

      // La poda deja su propio renglón, y en la misma transacción: sería el
      // único acto de la app sin rastro. Si el borrado se revierte, este se va
      // con él.
      if (cuantas > 0) {
        await anotar(
          Anotacion(
            entidad: EntidadAuditada.configuracion,
            accion: AccionAuditada.elimino,
            descripcion: 'Bitácora anterior a ${corte.toIso8601String()}',
            detalle: '$cuantas anotaciones podadas',
          ),
        );
      }

      return cuantas;
    });
  }

  /// La fecha antes de la cual se puede podar.
  ///
  /// El recorte a [mesesMinimos] es lo que evita que pedir doce meses reviente
  /// contra la guarda de la base con un error de SQLite en vez de borrar de
  /// menos. Ver `RepositorioBitacora.podar`.
  DateTime _corte(int meses) {
    final conservados = meses < mesesMinimos ? mesesMinimos : meses;
    final ahora = DateTime.now();
    return DateTime(
      ahora.year,
      ahora.month - conservados,
      ahora.day,
      ahora.hour,
      ahora.minute,
      ahora.second,
    );
  }

  /// El renglón sin el nombre de quien lo hizo es ilegible, así que el `JOIN`
  /// va siempre. Son dos `innerJoin` porque el nombre vive en `personas` y la
  /// cuenta en `usuarios`.
  JoinedSelectStatement<HasResultSet, dynamic> _conAutor() {
    return _db.select(_tabla).join([
      innerJoin(_usuarios, _usuarios.id.equalsExp(_tabla.usuarioId)),
      innerJoin(_personas, _personas.id.equalsExp(_usuarios.personaId)),
    ]);
  }

  Expression<bool> _condicion(FiltroBitacora filtro) {
    Expression<bool> acumulado = const Constant(true);

    if (filtro.usuarioId != null) {
      acumulado = acumulado & _tabla.usuarioId.equals(filtro.usuarioId!);
    }
    if (filtro.entidad != null) {
      acumulado = acumulado & _tabla.entidad.equals(filtro.entidad!.codigo);
    }
    if (filtro.accion != null) {
      acumulado = acumulado & _tabla.accion.equals(filtro.accion!.codigo);
    }
    if (filtro.desde != null) {
      acumulado = acumulado & _tabla.creadoEn.isBiggerOrEqualValue(filtro.desde!);
    }
    if (filtro.hasta != null) {
      acumulado = acumulado & _tabla.creadoEn.isSmallerOrEqualValue(filtro.hasta!);
    }

    final busqueda = filtro.busqueda.trim();
    if (busqueda.isNotEmpty) {
      final patron = '%${busqueda.toLowerCase()}%';
      acumulado = acumulado &
          (_tabla.descripcion.lower().like(patron) |
              _personas.nombres.lower().like(patron));
    }

    return acumulado;
  }
}
