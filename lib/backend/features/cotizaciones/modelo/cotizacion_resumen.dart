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
  final int total;
  final String vigenciaHasta; // "YYYY-MM-DD"
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
    required this.total,
    required this.vigenciaHasta,
    this.notas,
    required this.creadoEn,
    this.cantidadItems = 0,
  });

  /// Estado calculado a partir de vigenciaHasta vs. hoy.
  EstadoCotizacion get estado {
    final hoy = DateTime.now();
    final vigencia = DateTime.tryParse(vigenciaHasta);
    if (vigencia == null) return EstadoCotizacion.vencida;
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final vigSinHora = DateTime(vigencia.year, vigencia.month, vigencia.day);
    final diff = vigSinHora.difference(hoySinHora).inDays;
    if (diff < 0) return EstadoCotizacion.vencida;
    if (diff <= 3) return EstadoCotizacion.porVencer;
    return EstadoCotizacion.vigente;
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
    int? total,
    String? vigenciaHasta,
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
      total: total ?? this.total,
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
        total,
        vigenciaHasta,
        creadoEn,
        cantidadItems,
      ];
}
