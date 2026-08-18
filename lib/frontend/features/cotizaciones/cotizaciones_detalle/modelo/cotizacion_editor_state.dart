import '../../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../../backend/features/cotizaciones/enum/enum_cotizacion.dart';
import '../../../../../backend/features/motos/modelo/moto.dart';
import '../../../../../core/iva_app.dart';
import 'item_cotizacion_editor.dart';

/// En qué punto está el guardado automático.
///
/// La cotización se persiste sola: no hay botón de guardar, así que la barra
/// superior tiene que decir en todo momento si lo que hay en pantalla ya está
/// en la base o no.
enum EstadoGuardado {
  /// Nada que guardar todavía. Una cotización nueva y vacía **no se crea**:
  /// quemaría un consecutivo `COT-` para nada.
  sinCambios,

  /// Hay cambios esperando a que se cumpla el retardo del guardado.
  pendiente,

  /// Escribiendo en la base ahora mismo.
  guardando,

  /// Todo lo de la pantalla está persistido.
  guardado,

  /// No se puede guardar y el usuario tiene que arreglar algo. El motivo va en
  /// [CotizacionEditorState.motivoBloqueo].
  bloqueado,
}

/// Todo lo que hay en pantalla mientras se arma una cotización: la cabecera,
/// las líneas y los filtros del catálogo de la izquierda.
///
/// Los filtros del catálogo viven aquí y no en el widget porque de ellos salen
/// las listas derivadas ([productosCotizacionProvider],
/// [serviciosCotizacionProvider]): filtrar dentro de `build()` repetiría el
/// trabajo en cada repintado.
final class CotizacionEditorState {
  const CotizacionEditorState({
    this.cotizacionId,
    this.numero = '',
    this.cliente,
    this.moto,
    required this.vigenciaHasta,
    this.notas = '',
    this.items = const [],
    this.guardado = EstadoGuardado.sinCambios,
    this.motivoBloqueo,
    this.tipoActivo = TipoItemCotizacion.producto,
    this.busquedaCatalogo = '',
    this.categoriaId,
  });

  final int? cotizacionId;

  /// Consecutivo que generó el repositorio (`COT-2026-0042`). Vacío en una
  /// cotización nueva: todavía no existe.
  final String numero;

  final Cliente? cliente;
  final Moto? moto;
  final DateTime vigenciaHasta;
  final String notas;
  final List<ItemCotizacionEditor> items;

  final EstadoGuardado guardado;

  /// Por qué no se puede guardar, ya redactado. Solo con [EstadoGuardado.bloqueado].
  final String? motivoBloqueo;

  /// Qué muestra el panel de catálogo: productos, servicios o el formulario de
  /// línea libre.
  final TipoItemCotizacion tipoActivo;
  final String busquedaCatalogo;

  /// `null` = todas las categorías. Solo aplica en modo producto.
  final int? categoriaId;

  bool get esEdicion => cotizacionId != null;

  /// Hay algo escrito que todavía no está en la base.
  bool get haySinGuardar =>
      guardado == EstadoGuardado.pendiente ||
      guardado == EstadoGuardado.bloqueado;

  int get subtotal => items.fold(0, (suma, i) => suma + i.subtotal);
  int get iva => ivaDe(subtotal);
  int get total => subtotal + iva;

  // Operaciones sobre las líneas. Van aquí y no en el notifier porque son
  // aritmética del estado: se pueden probar sin Riverpod de por medio, y el
  // notifier queda solo con el "cuándo" (validar, guardar, avisar).

  /// Agrega la línea o, si esa misma fila del catálogo ya está, le suma la
  /// cantidad en vez de duplicarla.
  CotizacionEditorState conItem(ItemCotizacionEditor nuevo) {
    final lista = [...items];
    final i = lista.indexWhere(
      (item) => item.esMismaQue(nuevo.tipo, nuevo.referenciaId),
    );
    if (i >= 0) {
      lista[i] = lista[i].copyWith(cantidad: lista[i].cantidad + nuevo.cantidad);
    } else {
      lista.add(nuevo);
    }
    return copyWith(items: lista);
  }

  /// Un índice fuera de rango o una cantidad inválida devuelven el mismo
  /// estado: no hay nada que cambiar y así el notifier no marca un guardado
  /// pendiente por un cambio que no ocurrió.
  CotizacionEditorState conCantidad(int indice, double cantidad) {
    if (indice < 0 || indice >= items.length || cantidad < 1) return this;
    final lista = [...items];
    lista[indice] = lista[indice].copyWith(cantidad: cantidad);
    return copyWith(items: lista);
  }

  CotizacionEditorState conPrecio(int indice, int precio) {
    if (indice < 0 || indice >= items.length || precio < 0) return this;
    final lista = [...items];
    lista[indice] = lista[indice].copyWith(precioUnitario: precio);
    return copyWith(items: lista);
  }

  CotizacionEditorState sinItem(int indice) {
    if (indice < 0 || indice >= items.length) return this;
    return copyWith(items: [...items]..removeAt(indice));
  }

  static const Object _sinCambio = Object();

  CotizacionEditorState copyWith({
    Object? cliente = _sinCambio,
    Object? moto = _sinCambio,
    DateTime? vigenciaHasta,
    String? notas,
    List<ItemCotizacionEditor>? items,
    EstadoGuardado? guardado,
    Object? motivoBloqueo = _sinCambio,
    TipoItemCotizacion? tipoActivo,
    String? busquedaCatalogo,
    Object? categoriaId = _sinCambio,
    int? cotizacionId,
    String? numero,
  }) =>
      CotizacionEditorState(
        cotizacionId: cotizacionId ?? this.cotizacionId,
        numero: numero ?? this.numero,
        cliente: identical(cliente, _sinCambio)
            ? this.cliente
            : cliente as Cliente?,
        moto: identical(moto, _sinCambio) ? this.moto : moto as Moto?,
        vigenciaHasta: vigenciaHasta ?? this.vigenciaHasta,
        notas: notas ?? this.notas,
        items: items ?? this.items,
        guardado: guardado ?? this.guardado,
        motivoBloqueo: identical(motivoBloqueo, _sinCambio)
            ? this.motivoBloqueo
            : motivoBloqueo as String?,
        tipoActivo: tipoActivo ?? this.tipoActivo,
        busquedaCatalogo: busquedaCatalogo ?? this.busquedaCatalogo,
        categoriaId: identical(categoriaId, _sinCambio)
            ? this.categoriaId
            : categoriaId as int?,
      );
}
