import 'package:equatable/equatable.dart';

import '../enum/enum_deudor.dart';

class DeudorResumen extends Equatable {
  const DeudorResumen({
    required this.id,
    required this.numero,
    required this.clienteId,
    required this.nombreCliente,
    this.motoId,
    this.nombreMoto,
    this.placaMoto,
    this.ordenId,
    this.numeroOrden,
    this.concepto,
    this.descuento = 0,
    required this.montoTotal,
    required this.montoPagado,
    required this.estado,
    this.fechaVencimiento,
    this.notas,
    required this.creadoEn,
  });

  final int id;
  final String numero;
  final int clienteId;
  final String nombreCliente;
  final int? motoId;
  final String? nombreMoto;
  final String? placaMoto;

  /// La orden que se cerró a crédito, cuando la deuda nació así. Con ella la
  /// ficha puede llevar a la orden, que es donde de verdad están las líneas.
  final int? ordenId;

  /// El consecutivo visible de esa orden (`ORD-0041`), ya resuelto por SQL
  /// para no abrir una consulta por fila.
  final String? numeroOrden;

  /// Si la deuda es el reflejo de una orden. Sus líneas no se tocan a mano:
  /// el repuesto ya salió del estante al anotarse en la orden.
  bool get vieneDeOrden => ordenId != null;

  /// Por qué se debe, si se escribió. Las líneas ya dicen qué se llevó, así
  /// que esto es opcional: sirve para nombrar el fiado («Reparación del
  /// motor») cuando el listado de repuestos no lo explica solo.
  final String? concepto;
  /// Rebaja sobre la suma de las líneas, en pesos. [montoTotal] ya la trae
  /// descontada: es lo que el cliente debe.
  final int descuento;

  final int montoTotal;
  final int montoPagado;
  final EstadoDeudor estado;
  final DateTime? fechaVencimiento;
  final String? notas;
  final DateTime creadoEn;

  int get saldo => (montoTotal - montoPagado).clamp(0, montoTotal);

  /// La moto en una línea, para las cabeceras. `null` si no se anotó ninguna.
  String? get descripcionMoto {
    final partes = [?nombreMoto, ?placaMoto];
    return partes.isEmpty ? null : partes.join(' · ');
  }

  double get porcentajePagado =>
      montoTotal > 0 ? (montoPagado / montoTotal).clamp(0.0, 1.0) : 0.0;

  /// Si la deuda sigue esperando plata. Es lo contrario de estar cerrada:
  /// `PAGADA` se cobró e `INCOBRABLE` se dio por perdida.
  bool get estaViva =>
      estado == EstadoDeudor.activa || estado == EstadoDeudor.vencida;

  /// Si el plazo se pasó. Son dos cosas a la vez y por eso están juntas: la
  /// marca `VENCIDA` que pone el usuario —puede darla por vencida antes de
  /// tiempo— y el calendario, que la vence sola en cuanto pasa la fecha.
  ///
  /// Una deuda cerrada no vence: ya no espera nada. Es la misma condición que
  /// aplica `RepositorioDeudores` en SQL, y tiene que seguir siéndolo para que
  /// el contador de «Vencidas» y el badge de la fila digan lo mismo.
  bool get estaVencida {
    if (!estaViva) return false;
    if (estado == EstadoDeudor.vencida) return true;
    final limite = fechaVencimiento;
    if (limite == null) return false;
    final hoy = DateTime.now();
    return limite.isBefore(DateTime(hoy.year, hoy.month, hoy.day));
  }

  @override
  List<Object?> get props => [
        id,
        numero,
        clienteId,
        nombreCliente,
        motoId,
        nombreMoto,
        placaMoto,
        ordenId,
        numeroOrden,
        concepto,
        descuento,
        montoTotal,
        montoPagado,
        estado,
        fechaVencimiento,
        notas,
        creadoEn,
      ];
}
