import '../modelo/entrada_bitacora.dart';

/// Una página de la bitácora: los renglones visibles y el total real.
final class PaginaBitacora {
  const PaginaBitacora({required this.items, required this.total});

  final List<EntradaBitacora> items;

  /// Cuántos renglones cumplen el filtro en total, no solo en esta página.
  final int total;

  static const vacia = PaginaBitacora(items: [], total: 0);
}

/// Criterios que se aplican **en SQL**, no recorriendo la lista.
final class FiltroBitacora {
  const FiltroBitacora({
    this.usuarioId,
    this.entidad,
    this.accion,
    this.desde,
    this.hasta,
    this.busqueda = '',
  });

  /// Solo lo que hizo esta cuenta.
  final int? usuarioId;

  final EntidadAuditada? entidad;
  final AccionAuditada? accion;

  /// Rango de fechas, inclusivo por los dos lados.
  final DateTime? desde;
  final DateTime? hasta;

  /// Texto libre contra la descripción («pastilla», «FRE-1123»).
  final String busqueda;

  bool get hayFiltro =>
      usuarioId != null ||
      entidad != null ||
      accion != null ||
      desde != null ||
      hasta != null ||
      busqueda.trim().isNotEmpty;
}

/// Quién hizo qué.
///
/// Es la contraparte de las columnas `usuario_id` de los documentos: aquéllas
/// dicen quién creó una venta y viven dentro de ella; ésta es la única que
/// puede contar **quién editó o borró** algo, porque sobrevive a la fila que
/// desapareció.
abstract class RepositorioBitacora {
  /// Deja el renglón, firmado por quien tiene la sesión abierta.
  ///
  /// **Se llama dentro de la transacción del cambio que anota.** Si la
  /// escritura se revierte, el renglón se va con ella: una bitácora que
  /// cuenta cosas que no pasaron es peor que no tenerla.
  Future<void> anotar(Anotacion anotacion);

  /// Una página del historial, del más reciente al más antiguo.
  Stream<PaginaBitacora> observarPagina({
    required FiltroBitacora filtro,
    required int pagina,
    required int tamano,
  });

  /// Lo último que se hizo sobre una fila concreta. Para la ficha de un
  /// producto o de un cliente: «modificado por Ana, hace dos días».
  Future<List<EntradaBitacora>> historialDe(
    EntidadAuditada entidad,
    int entidadId, {
    int limite = 20,
  });

  /// Cuántas anotaciones tienen más de [meses], ya recortado al piso.
  ///
  /// Es lo que el diálogo de poda enseña **antes** de borrar nada: «se van
  /// 1.240 renglones». Usa el mismo recorte que [podar], así que el número
  /// que se muestra es el que de verdad se va.
  Future<int> cuantasPodaria({required int meses});

  /// Borra las anotaciones con más de [meses] y devuelve cuántas se fueron.
  ///
  /// La bitácora crece un renglón por cada alta, edición y borrado de
  /// catálogo, y no tenía nada que la recortara. Esto es ese recorte, con dos
  /// candados:
  ///
  /// - **[meses] se recorta a [mesesMinimos]**, que es el mismo piso que la
  ///   guarda de la base impone con un `RAISE(ABORT)`. Sin el recorte, pedir
  ///   doce meses no borraría de menos: reventaría con un error de SQLite.
  ///   Cuánto conserva el taller por encima de ese piso lo dice
  ///   `ClaveConfiguracion.mesesBitacora`.
  /// - **La poda deja su propio renglón**, en la misma transacción. Sería el
  ///   único acto de la app sin rastro, y justo el que se usaría para tapar
  ///   los demás.
  ///
  /// Exige `USUARIOS_ADMINISTRAR`: no es leer la bitácora, es recortarla.
  Future<int> podar({required int meses});
}

/// El piso que ninguna poda baja: dos años.
///
/// Está aquí y no en la configuración porque **es una garantía**, y una
/// garantía configurable no lo es. La guarda de `guardas_sql.dart` lo repite
/// en SQL, que es donde de verdad manda: quien abra el `.sqlite` con un visor
/// tampoco puede borrar lo reciente.
const int mesesMinimos = 24;
