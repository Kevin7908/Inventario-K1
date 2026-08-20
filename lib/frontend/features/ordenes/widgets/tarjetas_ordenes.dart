import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/ventas/ordenes/enum/enum_ordenes.dart';
import '../../../share2/share2.dart';
import '../provider/ordenes_providers.dart';

/// La fila de cuatro contadores que encabeza el listado, como en el diseño.
///
/// Los números salen de un `COUNT` por estado en SQL, no de recorrer la lista
/// en memoria (§5 de las reglas de base de datos): la pantalla los necesita
/// aunque la búsqueda esté recortando la tabla, y contarlos sobre lo filtrado
/// diría algo distinto de lo que la etiqueta promete.
///
/// Cada tarjeta **filtra al tocarla**, y volver a tocar la activa quita el
/// filtro. El mockup las pinta como cajas informativas, pero teniéndolas ahí
/// con el conteo de cada estado, no dejar que filtren obligaría a un segundo
/// control que dijera lo mismo.
class TarjetasOrdenes extends ConsumerWidget {
  const TarjetasOrdenes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(ordenesResumenProvider).value;
    final activo = ref.watch(
      ordenesProvider.select((s) => s.value?.filtroEstado),
    );

    void filtrar(EstadoOrden? estado) =>
        ref.read(ordenesProvider.notifier).filtrarPorEstado(estado);

    return Row(
      children: [
        Expanded(
          child: TarjetaMetrica(
            valor: '${resumen?.total ?? 0}',
            etiqueta: 'Órdenes totales',
            activa: activo == null,
            alPresionar: () => filtrar(null),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TarjetaMetrica(
            valor: '${resumen?.enProceso ?? 0}',
            etiqueta: 'En proceso',
            colorValor: ColoresApp.statusWarning,
            activa: activo == EstadoOrden.abierta,
            alPresionar: () => filtrar(EstadoOrden.abierta),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TarjetaMetrica(
            valor: '${resumen?.pendientes ?? 0}',
            etiqueta: 'Pendientes',
            colorValor: ColoresApp.statusNeutral,
            activa: activo == EstadoOrden.lista,
            alPresionar: () => filtrar(EstadoOrden.lista),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TarjetaMetrica(
            valor: '${resumen?.completadas ?? 0}',
            etiqueta: 'Completadas',
            colorValor: ColoresApp.statusSuccess,
            activa: activo == EstadoOrden.entregada,
            alPresionar: () => filtrar(EstadoOrden.entregada),
          ),
        ),
      ],
    );
  }
}
