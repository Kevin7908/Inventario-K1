import 'package:equatable/equatable.dart';

import 'bloque_lineas.dart';
import 'movimiento_documento.dart';
import 'negocio_impreso.dart';

/// A quién se le emite el documento, con todo lo que la factura enseña de él.
///
/// Es un objeto y no seis parámetros sueltos de [DocumentoImprimible] porque
/// son un solo dato —la identidad del cliente— y porque así el traductor de
/// cada módulo arma la franja completa o no la arma: con seis parámetros
/// opcionales, cada uno acababa poniendo los tres que se acordaba.
///
/// **Todos los campos menos [nombre] son opcionales, y los vacíos no se
/// pintan.** El mostrador vende sin pedir cédula, y una factura con seis
/// etiquetas huérfanas se ve peor que una corta.
///
/// Parámetros:
/// - [nombre]: razón social o nombre de la persona.
/// - [documento]: cédula o NIT, con su tipo si lo hay («NIT 800.139.030-1»).
/// - [direccion], [ciudad], [telefono], [correo]: los de `personas`.
///
/// Ejemplo:
/// ```dart
/// DestinatarioImpreso(
///   nombre: cliente.nombreCompleto,
///   documento: cliente.documento,
///   telefono: cliente.telefono,
/// )
/// ```
class DestinatarioImpreso extends Equatable {
  const DestinatarioImpreso({
    required this.nombre,
    this.documento = '',
    this.direccion = '',
    this.ciudad = '',
    this.telefono = '',
    this.correo = '',
  });

  /// El que se pone cuando no se pidió identificación. Es el mismo rótulo que
  /// usa cualquier tirilla de mostrador, y evita que el bloque quede en blanco.
  static const consumidorFinal =
      DestinatarioImpreso(nombre: 'CONSUMIDOR FINAL');

  final String nombre;
  final String documento;
  final String direccion;
  final String ciudad;
  final String telefono;
  final String correo;

  /// `true` si hay algo que pintar además del nombre.
  bool get tieneDetalle => [
        documento,
        direccion,
        ciudad,
        telefono,
        correo,
      ].any((s) => s.isNotEmpty);

  /// Los campos cargados, en pares etiqueta/valor y en el orden del papel.
  ///
  /// Se arma aquí y no en el pintor para que la tirilla y la carta enseñen los
  /// mismos datos en el mismo orden: lo único que cambia entre las dos es cómo
  /// se acomodan, no cuáles son.
  List<(String, String)> get campos => [
        if (documento.isNotEmpty) ('Documento', documento),
        if (direccion.isNotEmpty) ('Dirección', direccion),
        if (ciudad.isNotEmpty) ('Ciudad', ciudad),
        if (telefono.isNotEmpty) ('Teléfono', telefono),
        if (correo.isNotEmpty) ('Correo', correo),
      ];

  @override
  List<Object?> get props => [
        nombre,
        documento,
        direccion,
        ciudad,
        telefono,
        correo,
      ];
}

/// El papel, sin saber de qué documento salió.
///
/// Es la pieza que evita tener una plantilla por módulo. El punto de venta, las
/// reservas, las cotizaciones y las órdenes son cuatro documentos con la misma
/// forma —un taller que emite, unas líneas, unos totales—, así que cada uno
/// **traduce** su modelo a este y el constructor de PDF pinta uno solo.
///
/// Si un módulo necesita algo que aquí no está, se agrega **aquí** y los cuatro
/// lo ganan. Lo que no se hace es una segunda plantilla: con dos, la letra
/// pequeña de la factura y la de la reserva empiezan a divergir el mismo día.
///
/// Parámetros:
/// - [negocio]: quién emite. Sale de la configuración, no se teclea.
/// - [titulo]: qué es este papel («Factura de venta», «Reserva»).
/// - [numero]: el consecutivo del documento, tal como se guardó.
/// - [fecha]: cuándo se emitió.
/// - [vencimiento]: hasta cuándo vale, si el documento tiene plazo. La
///   cotización lo usa para su vigencia y la deuda para su fecha de cobro; una
///   factura de mostrador va en `null` y el renglón no se pinta.
/// - [destinatario]: a quién. Opcional: el mostrador vende sin pedir cédula.
/// - [etiquetaDestinatario]: cómo se rotula ese bloque. «Cliente» en los cinco
///   documentos que salen del taller, «Proveedor» en la remisión de compra,
///   que es el único que entra. Es un parámetro y no un documento aparte
///   porque la franja es la misma —un nombre y unos datos que lo identifican—
///   y solo cambia el rótulo, igual que [tituloMovimientos].
/// - [atendidoPor]: quién lo registró en el sistema, para que el papel diga lo
///   mismo que la bitácora. Sale de la sesión.
/// - [etiquetaAtendidoPor]: su rótulo. Una compra no se «atiende», se recibe.
/// - [vendedor]: quién hizo la venta, si no es la misma persona que la
///   registró. Es un dato aparte y no un reemplazo de [atendidoPor] porque
///   responden preguntas distintas: uno es a quién reclamarle por el trato y
///   el otro es quién tecleó. En `null` el renglón no se pinta.
/// - [bloques]: las líneas, agrupadas. Un solo bloque sin título es lo normal;
///   una venta con repuestos y mano de obra usa dos.
/// - [subtotal], [descuento], [total]: en pesos enteros, como toda la app.
/// - [iva]: el impuesto del documento, **ya calculado**, o `null` para no
///   pintar el renglón. Aquí no se recalcula: la factura de hace un año se
///   cerró con la tasa de entonces.
/// - [etiquetaIva]: cómo se rotula. «IVA (19%)» donde el impuesto se le suma
///   a la base —la factura, la cotización, la orden— y «IVA (19%) incluido»
///   donde el total ya venía liquidado, como la deuda que hereda el de una
///   orden cerrada a crédito. Ver `core/iva_app.dart`.
/// - [movimientos]: los pagos recibidos, si el documento los tiene.
/// - [tituloMovimientos]: cómo se llama ese bloque en el papel. Una reserva
///   lista «Abonos recibidos»; una factura de mostrador, «Forma de pago». Es
///   un parámetro y no dos plantillas porque la tabla es la misma —fecha,
///   concepto, monto— y solo cambia el rótulo.
/// - [saldoPendiente]: lo que falta por pagar. En `null` no se pinta.
/// - [nota]: una línea libre al pie (condiciones, vigencia).
/// - [conFirmas]: si el pie lleva las dos rayas de «Elaborado por» y
///   «Recibido». Van en la factura y en la remisión —los papeles que alguien
///   firma al recibir la mercancía— y no en la cotización, que no se entrega
///   contra nada. La tirilla nunca las pinta: no hay dónde firmar.
///
/// Ejemplo:
/// ```dart
/// final doc = documentoDeVenta(venta: venta, negocio: negocio);
/// final bytes = await const ConstructorPdf().construir(doc);
/// ```
class DocumentoImprimible extends Equatable {
  const DocumentoImprimible({
    required this.negocio,
    required this.titulo,
    required this.numero,
    required this.fecha,
    this.vencimiento,
    this.destinatario,
    this.etiquetaDestinatario = 'Cliente',
    this.atendidoPor,
    this.etiquetaAtendidoPor = 'Atendido por',
    this.vendedor,
    required this.bloques,
    required this.subtotal,
    this.descuento = 0,
    this.iva,
    this.etiquetaIva = 'IVA',
    required this.total,
    this.movimientos = const [],
    this.tituloMovimientos = 'Abonos recibidos',
    this.saldoPendiente,
    this.nota,
    this.conFirmas = false,
  });

  final NegocioImpreso negocio;
  final String titulo;
  final String numero;
  final DateTime fecha;
  final DateTime? vencimiento;
  final DestinatarioImpreso? destinatario;
  final String etiquetaDestinatario;
  final String? atendidoPor;
  final String etiquetaAtendidoPor;
  final String? vendedor;
  final List<BloqueLineas> bloques;
  final int subtotal;
  final int descuento;
  final int? iva;
  final String etiquetaIva;
  final int total;
  final List<MovimientoDocumento> movimientos;
  final String tituloMovimientos;
  final int? saldoPendiente;
  final String? nota;
  final bool conFirmas;

  /// `true` si hay que pintar el bloque de abonos.
  bool get tieneMovimientos => movimientos.isNotEmpty;

  /// `true` si el renglón de descuento aporta algo. Un `$0` en un impreso solo
  /// hace ruido.
  bool get tieneDescuento => descuento > 0;

  /// El nombre del destinatario, o vacío si el documento no tiene ninguno.
  String get nombreDestinatario => destinatario?.nombre ?? '';

  @override
  List<Object?> get props => [
        negocio,
        titulo,
        numero,
        fecha,
        vencimiento,
        destinatario,
        etiquetaDestinatario,
        atendidoPor,
        etiquetaAtendidoPor,
        vendedor,
        bloques,
        subtotal,
        descuento,
        iva,
        etiquetaIva,
        total,
        movimientos,
        tituloMovimientos,
        saldoPendiente,
        nota,
        conFirmas,
      ];
}
