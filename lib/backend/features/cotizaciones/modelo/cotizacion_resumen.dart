import 'package:equatable/equatable.dart';

enum EstadoCotizacion { vigente, porVencer, vencida }

class CotizacionResumen extends Equatable {
  final int id;
  final String numero;
  final int? clienteId;
  final int? motoId;
  // Hydratados por JOIN
  final String nombreCliente;
  final String? telefonoCliente;
  final String nombreMoto;
  final int subtotal;

  /// Rebaja aplicada sobre el subtotal, en pesos.
  final int descuento;

  final int iva;
  /// Hasta cuándo se respeta el precio, a medianoche.
  final DateTime vigenciaHasta;
  final String? notas;
  final DateTime creadoEn;

  /// Cuántas líneas tiene la cotización. Lo cuenta SQLite con un `COUNT`
  /// correlacionado: el listado no carga los ítems para saber cuántos son.
  final int cantidadItems;

  const CotizacionResumen({
    required this.id,
    required this.numero,
    this.clienteId,
    this.motoId,
    this.nombreCliente = '',
    this.telefonoCliente,
    this.nombreMoto = '',
    required this.subtotal,
    this.descuento = 0,
    required this.iva,
    required this.vigenciaHasta,
    this.notas,
    required this.creadoEn,
    this.cantidadItems = 0,
  });

  /// Lo que se cobraría: las líneas menos el descuento.
  ///
  /// **No se le suma [iva]**: los precios del sistema ya lo traen dentro (ver
  /// `iva_app.dart`), y la columna guarda cuánto impuesto va contenido en este
  /// total, con la tasa del día en que se emitió.
  ///
  /// No es una columna. Era `subtotal + iva`, dos campos de su misma fila, y
  /// guardarlo solo abría la puerta a que se desincronizara.
  int get total => subtotal - descuento;

  /// Lo que queda del total una vez discriminado el IVA.
  int get baseSinIva => total - iva;

  /// Vigente, por vencer o vencida, según cuánto falta para [vigenciaHasta].
  ///
  /// Tampoco es una columna: un estado que depende de la fecha de hoy caduca
  /// solo, y guardarlo obligaría a recalcularlo todas las noches. La misma
  /// regla vive en SQL —`RepositorioCotizaciones` la usa en el `WHERE` y en
  /// los conteos—, y las dos salen de [diasParaVencer].
  EstadoCotizacion get estado => switch (diasParaVencer) {
        < 0 => EstadoCotizacion.vencida,
        <= 3 => EstadoCotizacion.porVencer,
        _ => EstadoCotizacion.vigente,
      };

  /// Días que faltan para que venza. Negativo si ya venció.
  int get diasParaVencer {
    final hoy = DateTime.now();
    return DateTime(
      vigenciaHasta.year,
      vigenciaHasta.month,
      vigenciaHasta.day,
    ).difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
  }

  CotizacionResumen copyWith({
    int? id,
    String? numero,
    int? clienteId,
    int? motoId,
    String? nombreCliente,
    String? telefonoCliente,
    String? nombreMoto,
    int? subtotal,
    int? descuento,
    int? iva,
    DateTime? vigenciaHasta,
    String? notas,
    DateTime? creadoEn,
    int? cantidadItems,
  }) {
    return CotizacionResumen(
      id: id ?? this.id,
      numero: numero ?? this.numero,
      clienteId: clienteId ?? this.clienteId,
      motoId: motoId ?? this.motoId,
      nombreCliente: nombreCliente ?? this.nombreCliente,
      telefonoCliente: telefonoCliente ?? this.telefonoCliente,
      nombreMoto: nombreMoto ?? this.nombreMoto,
      subtotal: subtotal ?? this.subtotal,
      descuento: descuento ?? this.descuento,
      iva: iva ?? this.iva,
      vigenciaHasta: vigenciaHasta ?? this.vigenciaHasta,
      notas: notas ?? this.notas,
      creadoEn: creadoEn ?? this.creadoEn,
      cantidadItems: cantidadItems ?? this.cantidadItems,
    );
  }

  @override
  List<Object?> get props => [
        id,
        numero,
        clienteId,
        motoId,
        subtotal,
        descuento,
        iva,
        vigenciaHasta,
        creadoEn,
        cantidadItems,
      ];
}
