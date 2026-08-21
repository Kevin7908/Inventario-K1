import '../../../../../backend/features/productos/repositorio/repositorio_producto.dart';
import '../../../../../backend/features/ordenes/enum/enum_ordenes.dart';
import '../../../../../core/iva_app.dart';
import 'linea_orden_editor.dart';

/// En qué punto está el guardado automático.
///
/// La orden se persiste sola: no hay botón de guardar, así que la barra
/// superior tiene que decir en todo momento si lo que hay en pantalla ya está
/// en la base o no.
enum EstadoGuardadoOrden {
  /// Todo lo de la pantalla está persistido y no hay nada esperando.
  guardado,

  /// Hay cambios esperando a que se cumpla el retardo del guardado.
  pendiente,

  /// Escribiendo en la base ahora mismo.
  guardando,

  /// La última escritura falló y el usuario tiene que arreglar algo. El motivo
  /// va en [OrdenEditorState.motivoBloqueo].
  bloqueado,
}

/// Todo lo que hay en pantalla mientras se arma una orden.
///
/// Se diferencia de `CotizacionEditorState` en que **la orden ya existe**: no
/// hay caso "todavía sin guardar". `ordenes_servicio.moto_id` y `cliente_id`
/// son `NOT NULL` —una orden es una moto en el taller, sin moto no es nada—,
/// así que el editor no puede abrirse antes de que exista la fila. Quien lo
/// abre pide moto y kilometraje primero, crea la orden, y recién entonces
/// llega aquí con un [ordenId] real.
///
/// Eso también evita el problema que tendría el otro camino: crear la orden
/// vacía al abrir el editor quemaría un consecutivo `ORD-` cada vez que
/// alguien entra y se arrepiente.
final class OrdenEditorState {
  const OrdenEditorState({
    required this.ordenId,
    required this.numero,
    required this.clienteId,
    required this.clienteNombre,
    required this.motoId,
    required this.motoDescripcion,
    required this.motoPlaca,
    required this.kilometrajeEntrada,
    required this.estado,
    this.diagnostico = '',
    this.observaciones = '',
    this.descuento = 0,
    this.lineas = const [],
    this.guardado = EstadoGuardadoOrden.guardado,
    this.motivoBloqueo,
    this.tipoActivo = TipoLineaOrden.repuesto,
    this.busquedaCatalogo = '',
    this.categoriaId,
    this.paginaCatalogo = 0,
  });

  /// Cuántas tarjetas trae cada página de la rejilla de productos.
  static const int tamanoPaginaCatalogo = 12;

  final int ordenId;

  /// Consecutivo visible, `ORD-0041`. Siempre lleno: lo asignó el repositorio
  /// al crear la orden.
  final String numero;

  final int clienteId;
  final String clienteNombre;
  final int motoId;
  final String motoDescripcion;
  final String motoPlaca;

  final int kilometrajeEntrada;
  final EstadoOrden estado;
  final String diagnostico;
  final String observaciones;

  /// Rebaja en pesos sobre el subtotal. El recorte lo hace el repositorio —el
  /// subtotal de una orden es la suma de tres tablas y ningún `CHECK` puede
  /// consultarlas—, así que aquí llega ya recortado.
  final int descuento;

  final List<LineaOrdenEditor> lineas;

  final EstadoGuardadoOrden guardado;

  /// Por qué falló la última escritura, ya redactado. Solo con
  /// [EstadoGuardadoOrden.bloqueado].
  final String? motivoBloqueo;

  /// Qué muestra el panel de catálogo: repuestos, servicios o el formulario de
  /// cargo suelto.
  final TipoLineaOrden tipoActivo;
  final String busquedaCatalogo;

  /// `null` = todas las categorías. Solo aplica en modo repuesto.
  final int? categoriaId;

  /// Página de la rejilla de productos, de base cero.
  final int paginaCatalogo;

  /// Traduce los filtros del panel a los que entiende el repositorio.
  ///
  /// `soloActivos` va fijo: un producto dado de baja no se monta en una moto.
  FiltroProductos get filtroProductos => FiltroProductos(
        busqueda: busquedaCatalogo,
        categoriaId: categoriaId,
        soloActivos: true,
      );

  /// Si todavía se le pueden agregar líneas.
  ///
  /// Una orden `ENTREGADA` o `ANULADA` está cerrada, y una guarda de la base
  /// rechaza cualquier tarea o repuesto nuevo (§3.4 de `REGLAS_BD.md`). La
  /// interfaz lo refleja en vez de dejar teclear contra una pared: es el mismo
  /// patrón que un documento confirmado en cualquier ERP —mientras es
  /// borrador se guarda solo; una vez emitido, deja de hacerlo.
  bool get editable =>
      estado == EstadoOrden.abierta || estado == EstadoOrden.lista;

  /// Si el inventario de esta orden ya volvió al estante.
  ///
  /// Los repuestos salen al anotarlos, así que mientras la orden viva su stock
  /// está afuera. Anularla es lo único que lo devuelve, y entonces el aviso
  /// del diálogo tiene que decir lo contrario de lo que decía.
  bool get inventarioDevuelto => estado == EstadoOrden.anulada;

  int get subtotal => lineas.fold(0, (suma, l) => suma + l.subtotal);

  /// Lo que se cobra: las líneas menos la rebaja. Nada que sumar después —los
  /// precios ya traen el IVA dentro (ver `iva_app.dart`)—, así que el
  /// descuento sale directo de lo que paga el cliente.
  int get total => subtotal - descuento;

  /// Cuánto del [total] es impuesto. Informativo: se extrae, no se suma.
  int get iva => ivaIncluidoEn(total);

  /// El técnico de la última tarea agregada, para precargar el selector.
  ///
  /// Una orden la suele trabajar el mismo mecánico de principio a fin: repetir
  /// su nombre en cada servicio es teclear lo mismo cuatro veces.
  int? get ultimoTecnicoId {
    for (final linea in lineas.reversed) {
      if (linea.tipo == TipoLineaOrden.servicio && linea.tecnicoId != null) {
        return linea.tecnicoId;
      }
    }
    return null;
  }

  /// Las líneas agrupadas por tipo, en el orden del enum, con el subtotal de
  /// cada grupo. Los grupos vacíos no salen.
  ///
  /// Es `static` y recibe la lista en vez de leer [lineas] para que la vista lo
  /// pueda llamar sobre lo que ya observa con `select`: **el `select` sigue
  /// siendo sobre `lineas`**, que conserva identidad cuando no cambia, así que
  /// esta pasada solo corre cuando cambiaron de verdad. Devolverlo desde un
  /// `select` propio no serviría: `List.==` compara identidad y una lista nueva
  /// nunca es igual a la anterior, así que notificaría en todos los cambios del
  /// editor —hasta al teclear en el diagnóstico.
  static List<GrupoLineasOrden> agrupar(List<LineaOrdenEditor> lineas) {
    final grupos = <GrupoLineasOrden>[];
    for (final tipo in TipoLineaOrden.values) {
      final delTipo = [
        for (final linea in lineas)
          if (linea.tipo == tipo) linea,
      ];
      if (delTipo.isEmpty) continue;
      grupos.add(
        GrupoLineasOrden(
          tipo: tipo,
          lineas: delTipo,
          subtotal: delTipo.fold(0, (suma, l) => suma + l.subtotal),
        ),
      );
    }
    return grupos;
  }

  /// Reemplaza una línea por su versión editada, para que el campo responda
  /// mientras el guardado espera su retardo.
  ///
  /// Las líneas se identifican por **tipo + id** y no solo por id: los tres
  /// tipos viven en tablas distintas, así que la tarea 3 y el repuesto 3
  /// existen a la vez.
  OrdenEditorState conLinea(LineaOrdenEditor editada) {
    final lista = [
      for (final linea in lineas)
        if (linea.tipo == editada.tipo && linea.id == editada.id)
          editada
        else
          linea,
    ];
    return copyWith(lineas: lista);
  }

  static const Object _sinCambio = Object();

  OrdenEditorState copyWith({
    String? numero,
    int? clienteId,
    String? clienteNombre,
    int? motoId,
    String? motoDescripcion,
    String? motoPlaca,
    int? kilometrajeEntrada,
    EstadoOrden? estado,
    String? diagnostico,
    String? observaciones,
    int? descuento,
    List<LineaOrdenEditor>? lineas,
    EstadoGuardadoOrden? guardado,
    Object? motivoBloqueo = _sinCambio,
    TipoLineaOrden? tipoActivo,
    String? busquedaCatalogo,
    Object? categoriaId = _sinCambio,
    int? paginaCatalogo,
  }) =>
      OrdenEditorState(
        ordenId: ordenId,
        numero: numero ?? this.numero,
        clienteId: clienteId ?? this.clienteId,
        clienteNombre: clienteNombre ?? this.clienteNombre,
        motoId: motoId ?? this.motoId,
        motoDescripcion: motoDescripcion ?? this.motoDescripcion,
        motoPlaca: motoPlaca ?? this.motoPlaca,
        kilometrajeEntrada: kilometrajeEntrada ?? this.kilometrajeEntrada,
        estado: estado ?? this.estado,
        diagnostico: diagnostico ?? this.diagnostico,
        observaciones: observaciones ?? this.observaciones,
        descuento: descuento ?? this.descuento,
        lineas: lineas ?? this.lineas,
        guardado: guardado ?? this.guardado,
        motivoBloqueo: identical(motivoBloqueo, _sinCambio)
            ? this.motivoBloqueo
            : motivoBloqueo as String?,
        tipoActivo: tipoActivo ?? this.tipoActivo,
        busquedaCatalogo: busquedaCatalogo ?? this.busquedaCatalogo,
        categoriaId: identical(categoriaId, _sinCambio)
            ? this.categoriaId
            : categoriaId as int?,
        paginaCatalogo: paginaCatalogo ?? this.paginaCatalogo,
      );
}

/// Un bloque de líneas del mismo tipo, con su subtotal.
///
/// A diferencia del de cotizaciones, las líneas **no viajan con su índice**:
/// cada una lleva su propio `id` de base de datos, que es lo que esperan
/// `eliminarLinea` y `cambiarPrecio`. Agrupar no puede desordenar nada.
final class GrupoLineasOrden {
  const GrupoLineasOrden({
    required this.tipo,
    required this.lineas,
    required this.subtotal,
  });

  final TipoLineaOrden tipo;
  final List<LineaOrdenEditor> lineas;
  final int subtotal;

  String get titulo => tipo.titulo;
}
