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
    required this.iva,
    required this.vigenciaHasta,
    this.notas,
    required this.creadoEn,
    this.cantidadItems = 0,
  });

  /// Lo que se cobraría: la suma de las líneas más el IVA de ese día.
  ///
  /// No es una columna. Era `subtotal + iva`, dos campos de su misma fila, y
  /// guardarlo solo abría la puerta a que se desincronizara.
  int get total => subtotal + iva;

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
        iva,
        vigenciaHasta,
        creadoEn,
        cantidadItems,
      ];
}
