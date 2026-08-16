import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/motos/modelo/moto.dart';
import '../../../share2/share2.dart';
import '../provider/motos_provider.dart';
import 'tarjeta_moto.dart';

/// Grilla paginada de tarjetas de moto.
///
/// Vive aparte de la vista porque es la única parte de la pestaña que observa
/// los datos: así el buscador y los chips no se reconstruyen cuando cambia la
/// página.
class GrillaMotos extends ConsumerWidget {
  const GrillaMotos({
    super.key,
    required this.alEditar,
    required this.alEliminar,
  });

  final ValueChanged<Moto> alEditar;
  final ValueChanged<Moto> alEliminar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estadoAsync = ref.watch(motosProvider);

    if (estadoAsync.isLoading && !estadoAsync.hasValue) {
      return const Center(
        child: CircularProgressIndicator(color: ColoresApp.goGreen),
      );
    }
    if (estadoAsync.hasError && !estadoAsync.hasValue) {
      return Center(
        child: Text(
          'Error al cargar motos: ${estadoAsync.error}',
          style: TipografiaApp.cuerpo,
        ),
      );
    }

    final motos = ref.watch(motosFiltradasProvider);
    if (motos.isEmpty) {
      return _Vacio(
        hayFiltro: ref.watch(
          motosProvider.select((s) => s.value?.hayFiltro ?? false),
        ),
      );
    }

    final pagina = ref.watch(
      motosProvider.select((s) => (
            actual: s.value?.pagina ?? 0,
            total: s.value?.total ?? 0,
            paginas: s.value?.totalPaginas ?? 1,
            tamano: s.value?.tamanoPagina ?? 12,
          )),
    );

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(bottom: 8),
            // Mismas medidas que la grilla de clientes: el alto reserva sitio
            // para el título en dos líneas, la franja del dueño y la ficha.
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              mainAxisExtent: 204,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: motos.length,
            itemBuilder: (context, i) {
              final moto = motos[i];

              return TarjetaMoto(
                key: ValueKey(moto.id),
                moto: moto,
                alEditar: () => alEditar(moto),
                alEliminar: () => alEliminar(moto),
              );
            },
          ),
        ),
        if (pagina.paginas > 1)
          PaginacionWidget(
            paginaActual: pagina.actual,
            totalPaginas: pagina.paginas,
            totalItems: pagina.total,
            itemsPorPagina: pagina.tamano,
            alCambiarPagina: (p) =>
                ref.read(motosProvider.notifier).irAPagina(p),
          ),
      ],
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.hayFiltro});

  final bool hayFiltro;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.two_wheeler_outlined,
            size: 44,
            color: ColoresApp.textDisabled,
          ),
          const SizedBox(height: 14),
          Text(
            hayFiltro
                ? 'Ninguna moto coincide con el filtro'
                : 'Aún no hay motos registradas',
            style: TipografiaApp.subtitulo,
          ),
          const SizedBox(height: 6),
          Text(
            hayFiltro
                ? 'Prueba con otro término o quita el filtro de estado.'
                : 'Agrega la primera con "Nueva moto", o desde la ficha de un '
                    'cliente.',
            style: TipografiaApp.caption,
          ),
        ],
      ),
    );
  }
}
