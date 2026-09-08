/// Cómo se lee una fecha que viene cruda de un `customSelect`.
///
/// **Drift guarda `DateTime` como segundos desde la época**, no como
/// milisegundos. Con el query builder da igual —él hace la conversión—, pero
/// un `customSelect` devuelve el entero tal cual está en la columna, y ahí es
/// donde se pagaba: interpretar 1.788 millones de *segundos* como
/// milisegundos da veinte días, así que **todas** las ventas y **todas** las
/// órdenes salían fechadas el 21/01/1970.
///
/// Estaba escrito cuatro veces —dos bien y dos mal—, que es exactamente lo que
/// prohíbe `CLAUDE.md` §0: si hace falta parsear una fecha, primero se busca.
/// Ahora hay un solo sitio donde equivocarse.
library;

/// La fecha de una fila cruda, o `null` si la columna venía vacía.
///
/// Acepta las tres formas en las que puede llegar:
/// - `int`: los segundos de la época que guarda Drift;
/// - `DateTime`: si la consulta pasó por el query builder;
/// - `String`: si la columna se declaró como texto ISO.
///
/// Ejemplo:
/// ```dart
/// creadoEn: fechaDeSqlite(row['creado_en']),
/// ```
DateTime? fechaDeSqlite(Object? valor) => switch (valor) {
      null => null,
      final DateTime fecha => fecha,
      final int segundos =>
        DateTime.fromMillisecondsSinceEpoch(segundos * 1000),
      final String texto when texto.isNotEmpty => DateTime.tryParse(texto),
      _ => null,
    };

/// [fechaDeSqlite] para las columnas `NOT NULL`.
///
/// Cae en [DateTime.now] si la columna llegó vacía, que solo puede pasar si la
/// consulta se equivocó de nombre de columna: un renglón sin fecha estorba
/// menos que una excepción en el mostrador.
DateTime fechaDeSqliteObligatoria(Object? valor) =>
    fechaDeSqlite(valor) ?? DateTime.now();
