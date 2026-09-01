import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';

/// Cómo se lee la moto de un documento sin repetir el JOIN en cada módulo.
///
/// Cotizaciones, reservas y deudores muestran los tres la misma cabecera —«a
/// qué moto es este documento»— y los tres tenían el mismo par de líneas
/// copiado. Al pasar `motos.marca` y `motos.modelo` a FK, ese par se convirtió
/// en cuatro tablas y copiarlo tres veces dejaba de ser gratis: basta que a
/// una se le olvide un `leftOuterJoin` para que los documentos sin moto
/// desaparezcan de su listado.
///
/// Vive en el módulo dueño del dato, como manda `CLAUDE.md` §0: no cabe en
/// `share` —conoce el esquema— y no es de ninguno de los tres que lo usan.
extension JoinMoto on AppDb {
  /// Los dos JOIN que traducen `motos.marca_id` y `motos.modelo_id` a texto.
  ///
  /// Los dos son `leftOuterJoin`, incluida la marca: en estos documentos la
  /// moto misma es opcional —hay fiados de mostrador y cotizaciones sueltas—,
  /// y un `innerJoin` sobre la marca se llevaría por delante justo esas filas.
  ///
  /// Van **después** del join a `motos` en la lista.
  List<Join<HasResultSet, dynamic>> get joinsCatalogoMoto => [
        leftOuterJoin(
          tablaMarcaMoto,
          tablaMarcaMoto.id.equalsExp(tablaMoto.marcaId),
        ),
        leftOuterJoin(
          tablaModeloMoto,
          tablaModeloMoto.id.equalsExp(tablaMoto.modeloId),
        ),
      ];

  /// «Yamaha FZ 2.0 2020», con lo que haya. Devuelve `null` si el documento no
  /// tiene moto.
  ///
  /// [conAnio] lo pide quien ya lo mostraba así; deudores no, porque su
  /// cabecera es más estrecha.
  String? nombreMotoDe(TypedResult row, {bool conAnio = true}) {
    final moto = row.readTableOrNull(tablaMoto);
    if (moto == null) return null;

    final partes = <String>[
      row.readTableOrNull(tablaMarcaMoto)?.nombre ?? '',
      row.readTableOrNull(tablaModeloMoto)?.nombre ?? '',
      if (conAnio && moto.anio != null) '${moto.anio}',
    ];
    return partes.where((p) => p.isNotEmpty).join(' ');
  }
}
