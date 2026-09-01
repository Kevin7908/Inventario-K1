import 'package:equatable/equatable.dart';

import '../enum/enum_compras.dart';
import 'compra_item.dart';

/// Una fila del listado de compras.
///
/// [lineas] llega **ya contada por SQLite**: la lista lo muestra en cada fila
/// y abrir cada compra para contarlas sería el N+1 que prohíbe §5.
final class CompraResumen extends Equatable {
  const CompraResumen({
    required this.id,
    required this.numero,
    required this.proveedorId,
    required this.proveedorNombre,
    this.numeroFactura,
    required this.fecha,
    required this.total,
    required this.estado,
    this.lineas = 0,
    this.notas,
    required this.creadoEn,
  });

  final int id;

  /// El consecutivo del taller, `COM-2026-0007`.
  final String numero;

  final int proveedorId;
  final String proveedorNombre;

  /// El número que trae impreso el papel del proveedor, si lo trae.
  final String? numeroFactura;

  /// Cuándo llegó la mercancía.
  final DateTime fecha;

  /// Lo que costó la remisión completa, en pesos enteros.
  final int total;

  final EstadoCompra estado;

  /// Cuántos productos distintos trae.
  final int lineas;

  final String? notas;
  final DateTime creadoEn;

  bool get anulada => estado == EstadoCompra.anulada;

  @override
  List<Object?> get props => [
        id,
        numero,
        proveedorId,
        proveedorNombre,
        numeroFactura,
        fecha,
        total,
        estado,
        lineas,
        notas,
        creadoEn,
      ];
}

/// La remisión con sus líneas: lo que se ve al abrirla.
final class CompraDetalle {
  const CompraDetalle({required this.resumen, required this.items});

  final CompraResumen resumen;

  /// Las líneas en el orden en que se tecleó la remisión.
  final List<CompraItem> items;

  /// Lo que suman las líneas. Tiene que coincidir con `resumen.total`, que es
  /// el caché; `RepositorioCompras.descuadres()` es quien lo afirma.
  int get suma => items.fold(0, (t, i) => t + i.subtotal);
}
