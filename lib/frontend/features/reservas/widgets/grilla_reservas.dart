import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/reservas/modelo/reserva_resumen.dart';
import '../../../share2/share2.dart';
import '../provider/reservas_providers.dart';
import 'tarjeta_reserva.dart';

/// La rejilla de tarjetas del listado, con su paginador debajo.
///
/// Es lo único de la pantalla que cambia al buscar o al pasar de página, así
/// que va en su propio widget: escribir en el buscador no reconstruye el
/// encabezado (§2 de `CLAUDE.md`).
///
/// El ancho de columna sale del diseño —`minmax(360px, 1fr)`—, que en Flutter
/// es `maxCrossAxisExtent`: reparte en tantas columnas como quepan sin que
/// ninguna pase de ese ancho.
class GrillaReservas extends ConsumerWidget {
  const GrillaReservas({super.key, required this.alAbrir});

  final ValueChanged<ReservaResumen> alAbrir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(reservasListaProvider);

    return estado.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: ColoresApp.goGreen),
      ),
      error: (e, _) => EstadoVacio(
        icono: Icons.error_outline_rounded,
        titulo: 'No se pudo cargar el listado',
        pista: '$e',
      ),
      data: (datos) {
        if (datos.items.isEmpty) {
          return EstadoVacio(
            icono: Icons.bookmark_border_rounded,
            titulo: datos.hayFiltro
                ? 'Ninguna reserva coincide'
                : 'Todavía no hay reservas',
            pista: datos.hayFiltro
                ? 'Prueba con otro nombre o número.'
                : 'Aparta mercancía para un cliente con «Nueva reserva».',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: GridView.builder(
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 420,
                  mainAxisExtent: 224,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: datos.items.length,
                itemBuilder: (context, i) {
                  final reserva = datos.items[i];
                  return TarjetaReserva(
                    key: ValueKey(reserva.id),
                    reserva: reserva,
                    alPresionar: () => alAbrir(reserva),
                  );
                },
              ),
            ),
            if (datos.totalPaginas > 1) ...[
              const SizedBox(height: 16),
              PaginacionWidget(
                paginaActual: datos.pagina,
                totalPaginas: datos.totalPaginas,
                totalItems: datos.total,
                itemsPorPagina: datos.tamanoPagina,
                alCambiarPagina:
                    ref.read(reservasListaProvider.notifier).irAPagina,
              ),
            ],
          ],
        );
      },
    );
  }
}
