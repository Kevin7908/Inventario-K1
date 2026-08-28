import '../../../../../backend/features/cotizaciones/enum/enum_cotizacion.dart';
import '../../../../../backend/features/cotizaciones/repositorio/repositorio_cotizaciones.dart';

/// Una línea de la cotización mientras se está editando.
///
/// Es inmutable: cambiar la cantidad o el precio produce una línea nueva, de
/// modo que la lista del estado cambia de identidad y Riverpod notifica. La
/// versión anterior (`CotItemDraft`) tenía `cantidad` y `precioUnitario`
/// mutables y vivía dentro de un widget de diálogo, así que editarla no se
/// notaba y el modelo dependía de la interfaz.
///
/// [subtotal] es derivado, nunca un campo: guardarlo abriría la puerta a que
/// quedara desfasado de la cantidad y el precio que lo producen.
final class ItemCotizacionEditor {
  const ItemCotizacionEditor({
    required this.tipo,
    this.referenciaId,
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
  });

  final TipoItemCotizacion tipo;

  /// Id del producto o del servicio del catálogo. `null` en las líneas libres.
  final int? referenciaId;

  final String descripcion;
  final double cantidad;
  final int precioUnitario;

  int get subtotal => (cantidad * precioUnitario).round();

  /// Dos líneas son la misma cuando apuntan a la misma fila del mismo catálogo.
  /// Las líneas libres nunca coinciden: dos cargos escritos a mano son cosas
  /// distintas aunque se llamen igual.
  bool esMismaQue(TipoItemCotizacion otroTipo, int? otraReferencia) =>
      otraReferencia != null &&
      referenciaId == otraReferencia &&
      tipo == otroTipo;

  ItemCotizacionEditor copyWith({double? cantidad, int? precioUnitario}) =>
      ItemCotizacionEditor(
        tipo: tipo,
        referenciaId: referenciaId,
        descripcion: descripcion,
        cantidad: cantidad ?? this.cantidad,
        precioUnitario: precioUnitario ?? this.precioUnitario,
      );

  ItemDraft aDraft() => ItemDraft(
        tipo: tipo,
        referenciaId: referenciaId,
        descripcion: descripcion,
        cantidad: cantidad,
        precioUnitario: precioUnitario,
      );
}
