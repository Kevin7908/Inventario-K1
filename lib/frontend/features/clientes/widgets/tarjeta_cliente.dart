import 'package:flutter/material.dart';

import '../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../backend/features/clientes/repositorio/repositorio_cliente.dart';
import '../../../../backend/features/motos/repositorio/repositorio_motos.dart';
import '../../../../core/formato.dart';
import '../../../share2/share2.dart';

/// Tarjeta de un cliente en la grilla del catálogo.
///
/// Replica la tarjeta del mockup: avatar verde con las iniciales, nombre y
/// teléfono, y —en el pie— la moto principal con el conteo de vehículos y el
/// estado de cuenta. Vive en el módulo y no en share2 porque traduce un
/// [Cliente] —un modelo de dominio— a la [TarjetaCatalogo] compartida.
///
/// No lleva botones de editar ni eliminar: como en el diseño, la tarjeta
/// entera abre la ficha del cliente y es ahí donde viven esas acciones.
class TarjetaCliente extends StatelessWidget {
  const TarjetaCliente({
    super.key,
    required this.cliente,
    this.motos,
    this.saldo,
    this.alPresionar,
  });

  final Cliente cliente;

  /// Resumen de sus motos, ya calculado por un `GROUP BY`. `null` si el
  /// cliente no tiene ninguna.
  final ResumenMotosCliente? motos;

  /// Saldo pendiente, ya calculado sobre `deudores`. `null` = al día.
  final SaldoCliente? saldo;

  final VoidCallback? alPresionar;

  @override
  Widget build(BuildContext context) {
    final telefono = cliente.telefono?.trim() ?? '';

    return TarjetaCatalogo(
      marcador: MarcadorIdentidad(
        inicial: cliente.iniciales,
        color: ColoresApp.textOnPrimary,
        colorFondo: ColoresApp.goGreen,
        colorFondoFin: ColoresApp.castletonGreen,
        lado: 48,
        radio: 14,
      ),
      titulo: cliente.nombreCompleto,
      subtitulo: telefono.isEmpty ? null : telefono,
      alPresionar: alPresionar,
      // Solo se marca al inactivo: que un cliente siga siendo cliente es lo
      // normal y no necesita badge, igual que en la ficha.
      acciones: cliente.activo
          ? null
          : const IndicadorEstado(
              etiqueta: 'Inactivo',
              color: ColoresApp.statusNeutral,
              colorFondo: ColoresApp.statusNeutralBg,
            ),
      pie: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FranjaMotosCliente(motos: motos),
          const SizedBox(height: 10),
          FilaSaldoCliente(saldo: saldo),
        ],
      ),
    );
  }
}

/// Franja gris con la moto principal del cliente y cuántas tiene.
///
/// Se muestra siempre, incluso sin motos: el hueco en blanco descuadraría la
/// grilla, y "Sin motos registradas" es información útil de por sí.
class FranjaMotosCliente extends StatelessWidget {
  const FranjaMotosCliente({super.key, required this.motos});

  final ResumenMotosCliente? motos;

  @override
  Widget build(BuildContext context) {
    final resumen = motos;
    final cantidad = resumen?.cantidad ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: ColoresApp.bgInput,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.two_wheeler_outlined,
            size: 18,
            color: cantidad == 0
                ? ColoresApp.textDisabled
                : ColoresApp.textSecondary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  resumen?.principal ?? 'Sin motos registradas',
                  style: TipografiaApp.cuerpoMedium.copyWith(
                    fontSize: 12.5,
                    color: cantidad == 0
                        ? ColoresApp.textDisabled
                        : ColoresApp.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  cantidad == 1 ? '1 moto' : '$cantidad motos',
                  style: TipografiaApp.caption.copyWith(
                    fontSize: 11,
                    color: ColoresApp.textDisabled,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pie de la tarjeta: "Saldo" a la izquierda y el estado de cuenta a la
/// derecha, en rojo si debe y en verde si está al día.
///
/// El monto es real: sale de sumar las deudas vivas del cliente, no de una
/// marca guardada a mano que podría quedar desfasada del módulo de Deudores.
class FilaSaldoCliente extends StatelessWidget {
  const FilaSaldoCliente({super.key, required this.saldo});

  final SaldoCliente? saldo;

  @override
  Widget build(BuildContext context) {
    final pendiente = saldo?.pendiente ?? 0;
    final debe = pendiente > 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Saldo',
          style: TipografiaApp.caption.copyWith(
            fontSize: 12,
            color: ColoresApp.textMuted,
          ),
        ),
        IndicadorEstado(
          etiqueta: debe ? formatearPrecio(pendiente) : 'Al día',
          color: debe ? ColoresApp.statusDanger : ColoresApp.statusSuccess,
          colorFondo:
              debe ? ColoresApp.statusDangerBg : ColoresApp.statusSuccessBg,
        ),
      ],
    );
  }
}
