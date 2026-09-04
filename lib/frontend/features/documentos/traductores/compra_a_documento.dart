import '../../../../backend/features/compras/modelo/compra_item.dart';
import '../../../../backend/features/compras/modelo/compra_resumen.dart';
import '../../../../core/formato.dart';
import '../modelo/bloque_lineas.dart';
import '../modelo/documento_imprimible.dart';
import '../modelo/negocio_impreso.dart';

/// Traduce una compra a papel.
///
/// Es el único de los seis documentos que **entra** en vez de salir: los otros
/// cinco los emite el taller para un cliente, y este es el acta de lo que
/// llegó del proveedor. Se imprime para archivarlo con la factura de él y para
/// que quien recibió la mercancía firme lo que contó.
///
/// Decisiones que se toman aquí, y por qué:
///
/// - **El destinatario es el proveedor**, y el papel lo dice con esa palabra.
///   Es lo que agregó `etiquetaDestinatario` a `DocumentoImprimible`: la franja
///   es la misma —un nombre y el dato que lo identifica—, y rotularla «Cliente»
///   en una remisión de entrada sería decir lo contrario de lo que pasó.
/// - **No lleva IVA.** Quien factura con IVA en una compra es el proveedor, en
///   su propio papel; lo que el taller registra aquí es el costo que pagó.
///   Inventarse un renglón de IVA sobre ese costo sería afirmar algo que este
///   documento no sabe.
/// - **No lleva pagos ni saldo.** La cuenta con el proveedor no está modelada:
///   `compras` guarda lo que llegó, no lo que se le debe a quien lo trajo. Un
///   «Saldo pendiente $0» sugeriría que sí.
/// - **Una remisión anulada lo dice en el título**, como la factura anulada: su
///   mercancía volvió a salir del inventario y el papel no puede parecer el de
///   una entrada vigente.
/// - **Un borrador también se imprime.** Su mercancía ya entró al inventario
///   —anotar una línea *es* recibirla—, así que el papel refleja algo real; lo
///   que le falta es que alguien lo dé por terminado, y eso lo dice el título.
///
/// Parámetros:
/// - [compra]: la remisión con sus líneas.
/// - [negocio]: el encabezado, de `leerAjustesImpresion`.
/// - [recibidoPor]: quién contó la mercancía.
///
/// Ejemplo:
/// ```dart
/// final doc = documentoDeCompra(compra: detalle, negocio: ajustes.negocio);
/// ```
DocumentoImprimible documentoDeCompra({
  required CompraDetalle compra,
  required NegocioImpreso negocio,
  String? recibidoPor,
}) {
  final resumen = compra.resumen;

  return DocumentoImprimible(
    negocio: negocio,
    titulo: resumen.anulada ? 'Remisión anulada' : 'Remisión de entrada',
    numero: resumen.numero,
    fecha: resumen.fecha,
    cliente: resumen.proveedorNombre,
    documentoCliente: (resumen.numeroFactura ?? '').isEmpty
        ? null
        : 'Factura ${resumen.numeroFactura}',
    etiquetaDestinatario: 'Proveedor',
    atendidoPor: recibidoPor,
    etiquetaAtendidoPor: 'Recibido por',
    bloques: [
      BloqueLineas(lineas: compra.items.map(_linea).toList()),
    ],
    // El total es el caché de la cabecera y el subtotal la suma de las
    // líneas. Se pintan los dos a propósito: si algún día dejan de coincidir,
    // el papel lo enseña —es la misma pregunta que responde
    // `RepositorioCompras.descuadres()`, pero en la mano de quien recibe—.
    subtotal: compra.suma,
    total: resumen.total,
    nota: _pie(resumen, compra.items.length),
  );
}

/// Cuántas líneas trae y lo que se haya anotado a mano. El conteo va en el
/// papel porque es lo que se coteja contra las cajas al descargarlas.
String _pie(CompraResumen resumen, int lineas) {
  final conteo = lineas == 1 ? '1 producto' : '$lineas productos';
  final estado = resumen.anulada
      ? 'Anulada: esta mercancía volvió a salir del inventario.'
      : resumen.estado.etiqueta;
  final notas = (resumen.notas ?? '').trim();

  return [
    '$conteo · $estado · recibida el ${formatearFecha(resumen.fecha)}.',
    if (notas.isNotEmpty) notas,
  ].join('  ');
}

/// El costo unitario ocupa la columna del precio: en una remisión de entrada,
/// «a cómo salió» es a cómo se compró, no a cómo se vende.
LineaDocumento _linea(CompraItem item) => LineaDocumento(
      descripcion: item.descripcion,
      referencia: item.sku,
      cantidad: item.cantidad,
      precioUnitario: item.costoUnitario,
      subtotal: item.subtotal,
    );
