import 'package:drift/drift.dart';

import '../database/app_db.dart';
import 'documento_consecutivo.dart';

/// Reparte los números de documento, uno por uno y sin repetir.
///
/// Se llama **dentro** de la transacción que crea el documento: Drift la
/// propaga por zona mientras se use la misma instancia de [AppDb]. Eso es lo
/// que garantiza que un documento que no llega a guardarse tampoco consuma su
/// número.
class RepositorioConsecutivos {
  RepositorioConsecutivos(this._db);

  final AppDb _db;

  /// El siguiente número visible de [documento], del estilo `FAC-0007`.
  Future<String> siguiente(DocumentoConsecutivo documento) async {
    final periodo = documento.periodoDe(DateTime.now());
    final secuencia = await _incrementar(documento.codigo, periodo);
    return documento.formatear(secuencia, periodo: periodo);
  }

  /// El siguiente número de una serie que **no** está en
  /// [DocumentoConsecutivo], porque su código no se conoce hasta que corre la
  /// app: el SKU lleva una serie por categoría y las categorías las crea el
  /// usuario.
  ///
  /// Sigue siendo el mismo `UPSERT ... RETURNING`, así que hereda lo que hace
  /// falta: no repite, no reutiliza el número de lo borrado, y una transacción
  /// revertida devuelve el número a la serie.
  Future<int> siguienteDeSerie(String codigo) => _incrementar(codigo, 0);

  /// Lo que devolvería [siguienteDeSerie] **sin consumirlo**.
  ///
  /// Es para enseñar el número antes de guardar. Abrir un formulario y
  /// arrepentirse no puede quemar un código: quien mira una estantería con
  /// `ACE-003` y `ACE-005` se pregunta dónde está el cuarto.
  Future<int> proximoDeSerie(String codigo) async {
    final fila = await (_db.select(_db.tablaConsecutivo)
          ..where((c) => c.documento.equals(codigo) & c.periodo.equals(0)))
        .getSingleOrNull();
    return (fila?.ultimo ?? 0) + 1;
  }

  /// Incrementa el contador y devuelve el valor nuevo, en una sola sentencia.
  ///
  /// `ON CONFLICT ... RETURNING` evita el ciclo «leer → sumar → escribir», que
  /// es donde se colaba la carrera de las cuatro implementaciones anteriores.
  Future<int> _incrementar(String codigo, int periodo) async {
    final fila = await _db.customSelect(
      '''
      INSERT INTO consecutivos (documento, periodo, ultimo)
      VALUES (?1, ?2, 1)
      ON CONFLICT (documento, periodo)
        DO UPDATE SET ultimo = ultimo + 1
      RETURNING ultimo
      ''',
      variables: [Variable.withString(codigo), Variable.withInt(periodo)],
      readsFrom: {_db.tablaConsecutivo},
    ).getSingle();

    return fila.read<int>('ultimo');
  }
}
