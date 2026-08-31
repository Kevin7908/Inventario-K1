import '../../../../backend/features/ordenes/modelo/orden_cargo.dart';
import '../../../../backend/features/ordenes/modelo/orden_detalle.dart';
import '../../../../backend/features/ordenes/modelo/orden_repuesto.dart';
import '../../../../backend/features/ordenes/modelo/orden_tarea.dart';
import '../../../../core/iva_app.dart';
import '../modelo/bloque_lineas.dart';
import '../modelo/documento_imprimible.dart';
import '../modelo/negocio_impreso.dart';

/// Traduce una orden de servicio a papel.
///
/// Es el documento más largo de los cuatro, y el único con **tres** grupos de
/// líneas: mano de obra, repuestos y cargos sueltos. Aquí los títulos van
/// siempre que el grupo tenga algo —a diferencia de la factura, donde se
/// omiten si hay uno solo—: en una orden el cliente necesita distinguir qué
/// paga por trabajo y qué por pieza, aunque solo haya de uno.
///
/// Decisiones que se toman aquí:
///
/// - **La mano de obra dice quién la hizo.** El técnico va como referencia de
///   la línea, que es lo que el cliente pregunta cuando algo vuelve a fallar.
/// - **La moto identifica la orden**, con su placa: es lo que se busca en el
///   mostrador, no el nombre del dueño.
/// - **El kilometraje y el diagnóstico van al pie.** No son importes, pero son
///   la razón de ser del documento y lo que se compara en la visita siguiente.
/// - **El IVA se calcula** con `ivaIncluidoEn`: una orden no lo guarda como lo
///   hace una factura, y los precios lo llevan dentro.
///
/// Parámetros:
/// - [orden]: la orden con sus tareas, repuestos y cargos.
/// - [negocio]: el encabezado, de `leerNegocioImpreso`.
/// - [atendidoPor]: quién la entrega.
///
/// Ejemplo:
/// ```dart
/// final doc = documentoDeOrden(orden: detalle, negocio: negocio);
/// ```
DocumentoImprimible documentoDeOrden({
  required OrdenDetalle orden,
  required NegocioImpreso negocio,
  String? atendidoPor,
}) {
  return DocumentoImprimible(
    negocio: negocio,
    titulo: 'Orden de servicio',
    numero: orden.numeroOrden,
    fecha: orden.fechaIngreso ?? DateTime.now(),
    cliente: orden.clienteNombre,
    documentoCliente: _moto(orden.motoDescripcion, orden.motoPlaca),
    atendidoPor: atendidoPor,
    bloques: [
      if (orden.tareas.isNotEmpty)
        BloqueLineas(
          titulo: 'Mano de obra',
          lineas: orden.tareas.map(_deTarea).toList(),
        ),
      if (orden.repuestos.isNotEmpty)
        BloqueLineas(
          titulo: 'Repuestos',
          lineas: orden.repuestos.map(_deRepuesto).toList(),
        ),
      if (orden.cargos.isNotEmpty)
        BloqueLineas(
          titulo: 'Otros cargos',
          lineas: orden.cargos.map(_deCargo).toList(),
        ),
    ],
    subtotal: orden.subtotal,
    descuento: orden.descuento,
    iva: hayIva ? ivaIncluidoEn(orden.total) : null,
    total: orden.total,
    nota: _pie(orden),
  );
}

String? _moto(String descripcion, String placa) {
  final partes = [
    if (descripcion.isNotEmpty) descripcion,
    if (placa.isNotEmpty) placa,
  ];
  return partes.isEmpty ? null : partes.join(' · ');
}

/// Kilometraje y diagnóstico: lo que hace que la orden sirva de historial.
String? _pie(OrdenDetalle orden) {
  final partes = <String>[
    if (orden.kilometrajeEntrada > 0)
      'Kilometraje de entrada: ${orden.kilometrajeEntrada} km.',
    if ((orden.diagnosticoCliente ?? '').trim().isNotEmpty)
      'Reportado: ${orden.diagnosticoCliente!.trim()}',
    if ((orden.observacionesMecanico ?? '').trim().isNotEmpty)
      'Observaciones: ${orden.observacionesMecanico!.trim()}',
  ];
  return partes.isEmpty ? null : partes.join('  ');
}

LineaDocumento _deTarea(OrdenTarea tarea) => LineaDocumento(
      descripcion: tarea.servicioNombre,
      referencia: tarea.tecnicoNombre.isEmpty
          ? null
          : 'Técnico: ${tarea.tecnicoNombre}',
      cantidad: 1,
      precioUnitario: tarea.precioPactado,
      subtotal: tarea.precioPactado,
    );

LineaDocumento _deRepuesto(OrdenRepuesto repuesto) => LineaDocumento(
      descripcion: repuesto.productoNombre,
      cantidad: repuesto.cantidad,
      precioUnitario: repuesto.precioUnitario,
      subtotal: repuesto.subtotal,
    );

LineaDocumento _deCargo(OrdenCargo cargo) => LineaDocumento(
      descripcion: cargo.descripcion,
      cantidad: 1,
      precioUnitario: cargo.precio,
      subtotal: cargo.precio,
    );
