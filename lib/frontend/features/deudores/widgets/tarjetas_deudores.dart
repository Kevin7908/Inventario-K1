import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/deudores/repositorio/repositorio_deudores.dart';
import '../../../../core/formato.dart';
import '../../../share/share.dart';
import '../provider/deudores_providers.dart';

/// La fila de cuatro contadores que encabeza la cartera.
///
/// Los números salen de un `SUM`/`COUNT` en SQL, no de recorrer la lista en
/// memoria (§5 de `REGLAS_BD.md`): la pantalla los necesita aunque la búsqueda
/// esté recortando la tabla, y contarlos sobre lo filtrado diría algo distinto
/// de lo que promete la etiqueta.
///
/// **La primera es plata y las otras tres son cuentas.** «Total por cobrar» es
/// la caja oscura del diseño y responde la pregunta que trae al usuario a esta
/// pantalla; tocarla quita el filtro y devuelve la cartera entera.
///
/// Cada tarjeta filtra al tocarla, y volver a tocar la activa lo quita: es el
/// mismo gesto de las órdenes.
class TarjetasDeudores extends ConsumerWidget {
  const TarjetasDeudores({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(resumenCarteraProvider).value;
    final vista = ref.watch(
      deudoresListaProvider.select((s) => s.value?.vista ?? VistaDeudores.todas),
    );

    void filtrar(VistaDeudores destino) =>
        ref.read(deudoresListaProvider.notifier).filtrarPorVista(destino);

    return Row(
      children: [
        Expanded(
          child: TarjetaMetrica(
            // Compacto porque la cartera de un taller llega a los millones y
            // el número entero no cabe en un cuarto de fila.
            valor: formatearPrecioCompacto(resumen?.porCobrar ?? 0),
            etiqueta: 'Total por cobrar',
            colorValor: ColoresApp.goGreen,
            activa: vista == VistaDeudores.todas,
            alPresionar: () => filtrar(VistaDeudores.todas),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TarjetaMetrica(
            valor: '${resumen?.alDia ?? 0}',
            etiqueta: 'Al día',
            colorValor: ColoresApp.statusNeutral,
            activa: vista == VistaDeudores.alDia,
            alPresionar: () => filtrar(VistaDeudores.alDia),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TarjetaMetrica(
            valor: '${resumen?.vencidas ?? 0}',
            etiqueta: 'Vencidas',
            colorValor: ColoresApp.statusDanger,
            activa: vista == VistaDeudores.vencidas,
            alPresionar: () => filtrar(VistaDeudores.vencidas),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TarjetaMetrica(
            valor: '${resumen?.pagadas ?? 0}',
            etiqueta: 'Pagadas',
            colorValor: ColoresApp.statusSuccess,
            activa: vista == VistaDeudores.pagadas,
            alPresionar: () => filtrar(VistaDeudores.pagadas),
          ),
        ),
      ],
    );
  }
}
