import '../../../../../backend/features/compras/enum/enum_compras.dart';
import '../../../../../backend/features/compras/modelo/compra_item.dart';
import '../../../../../backend/features/productos/repositorio/repositorio_producto.dart';

/// En qué punto va el guardado automático.
enum EstadoGuardadoCompra { guardado, pendiente, guardando, bloqueado }

/// Todo lo que la ficha de una remisión necesita para pintarse.
final class CompraEditorState {
  const CompraEditorState({
    required this.compraId,
    required this.numero,
    required this.proveedorId,
    required this.proveedorNombre,
    required this.fecha,
    required this.estado,
    required this.total,
    this.numeroFactura,
    this.notas,
    this.lineas = const [],
    this.busquedaCatalogo = '',
    this.categoriaId,
    this.paginaCatalogo = 0,
    this.guardado = EstadoGuardadoCompra.guardado,
    this.motivoBloqueo,
  });

  /// Cuántos productos trae la rejilla del panel izquierdo.
  static const int tamanoPaginaCatalogo = 12;

  final int compraId;
  final String numero;
  final int proveedorId;
  final String proveedorNombre;

  /// El número que trae impreso el papel del proveedor, si lo trae.
  final String? numeroFactura;

  /// Cuándo llegó la mercancía, que no siempre es cuándo se teclea.
  final DateTime fecha;

  final EstadoCompra estado;
  final String? notas;

  /// El total viene de la base, no se calcula aquí: es un caché que el
  /// repositorio mantiene, y espejarlo en Dart era la forma de que se
  /// desviara.
  final int total;

  /// Lo que llegó, tal como está en la base.
  final List<CompraItem> lineas;

  final String busquedaCatalogo;
  final int? categoriaId;
  final int paginaCatalogo;

  final EstadoGuardadoCompra guardado;
  final String? motivoBloqueo;

  /// Si todavía se le pueden mover líneas: **solo mientras sea borrador**.
  ///
  /// Darla por terminada es lo que la cierra, y una anulada además ya devolvió
  /// su mercancía. Es la misma condición que aplica el repositorio para
  /// rechazarlo —y la guarda de la base para impedirlo—, así que la interfaz y
  /// la garantía no pueden decir cosas distintas.
  bool get editable => estado.admiteCambios;

  /// Si se puede dar por terminada: es borrador y trajo algo. Una remisión sin
  /// una sola línea no es un documento.
  bool get puedeTerminar => editable && lineas.isNotEmpty;

  /// El cuadro que se abrió y en el que no se anotó nada. Al salir se
  /// descarta: si no, el listado se llenaría de remisiones vacías.
  bool get vacia => lineas.isEmpty;

  /// Por qué no se puede tocar, para poder decirlo en pantalla. `null` cuando
  /// sí se puede.
  String? get motivoNoEditable => switch (estado) {
        EstadoCompra.borrador => null,
        EstadoCompra.registrada =>
          'La compra está terminada: para cambiarla hay que anularla.',
        EstadoCompra.anulada =>
          'La compra está anulada: su mercancía ya salió del inventario.',
      };

  /// Cuántas unidades trae en total, para el contador de la cabecera.
  double get unidades => lineas.fold(0, (t, l) => t + l.cantidad);

  /// Traduce los filtros del panel a los que entiende el repositorio.
  ///
  /// **Sin `soloActivos`**: un producto dado de baja se puede seguir
  /// recibiendo —el proveedor manda lo que manda— y hay que poder darle
  /// entrada para cuadrar el inventario.
  FiltroProductos get filtroProductos => FiltroProductos(
        busqueda: busquedaCatalogo,
        categoriaId: categoriaId,
      );

  CompraEditorState copyWith({
    String? numero,
    int? proveedorId,
    String? proveedorNombre,
    Object? numeroFactura = _sinCambio,
    DateTime? fecha,
    EstadoCompra? estado,
    Object? notas = _sinCambio,
    int? total,
    List<CompraItem>? lineas,
    String? busquedaCatalogo,
    Object? categoriaId = _sinCambio,
    int? paginaCatalogo,
    EstadoGuardadoCompra? guardado,
    String? motivoBloqueo,
  }) =>
      CompraEditorState(
        compraId: compraId,
        numero: numero ?? this.numero,
        proveedorId: proveedorId ?? this.proveedorId,
        proveedorNombre: proveedorNombre ?? this.proveedorNombre,
        numeroFactura: identical(numeroFactura, _sinCambio)
            ? this.numeroFactura
            : numeroFactura as String?,
        fecha: fecha ?? this.fecha,
        estado: estado ?? this.estado,
        notas: identical(notas, _sinCambio) ? this.notas : notas as String?,
        total: total ?? this.total,
        lineas: lineas ?? this.lineas,
        busquedaCatalogo: busquedaCatalogo ?? this.busquedaCatalogo,
        categoriaId: identical(categoriaId, _sinCambio)
            ? this.categoriaId
            : categoriaId as int?,
        paginaCatalogo: paginaCatalogo ?? this.paginaCatalogo,
        guardado: guardado ?? this.guardado,
        motivoBloqueo: motivoBloqueo,
      );

  /// Centinela para distinguir «no tocar el campo» de «ponerlo en null», que
  /// con `??` serían lo mismo. Quitarle la factura o la nota a una remisión es
  /// una operación real.
  static const Object _sinCambio = Object();

  /// Reemplaza una línea conservando el orden. Lo usa el cambio de cantidad,
  /// que actualiza la pantalla antes de escribir.
  CompraEditorState conLinea(CompraItem editada) => copyWith(
        lineas: [
          for (final l in lineas)
            if (l.id == editada.id) editada else l,
        ],
      );
}
