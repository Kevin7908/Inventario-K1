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
