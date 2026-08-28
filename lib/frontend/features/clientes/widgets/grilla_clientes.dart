import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../share/share.dart';
import '../provider/cliente_provider.dart';
import 'tarjeta_cliente.dart';

/// Grilla paginada de tarjetas de cliente.
///
/// Vive aparte de la vista porque es la única parte de la pantalla que observa
/// los datos: así el encabezado, el buscador y los chips no se reconstruyen
/// cuando cambia la página.
class GrillaClientes extends ConsumerWidget {
  const GrillaClientes({super.key, required this.alAbrir});

  final ValueChanged<Cliente> alAbrir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estadoAsync = ref.watch(clientesProvider);

    if (estadoAsync.isLoading && !estadoAsync.hasValue) {
      return const Center(
        child: CircularProgressIndicator(color: ColoresApp.goGreen),
      );
    }
    if (estadoAsync.hasError && !estadoAsync.hasValue) {
      return Center(
        child: Text(
          'Error al cargar clientes: ${estadoAsync.error}',
          style: TipografiaApp.cuerpo,
        ),
      );
    }

    final clientes = ref.watch(clientesFiltradosProvider);
    if (clientes.isEmpty) {
      return _Vacio(
        hayFiltro: ref.watch(
          clientesProvider.select((s) => s.value?.hayFiltro ?? false),
        ),
      );
    }

    final motos = ref.watch(resumenMotosPorClienteProvider).value ?? const {};
    final saldos = ref.watch(saldosClientesProvider).value ?? const {};

    final pagina = ref.watch(
      clientesProvider.select((s) => (
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
            // El mockup usa `minmax(320px, 1fr)`. El alto reserva sitio para
            // el nombre en dos líneas, la franja de motos y la fila de saldo.
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              mainAxisExtent: 204,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: clientes.length,
            itemBuilder: (context, i) {
              final cliente = clientes[i];

              return TarjetaCliente(
                key: ValueKey(cliente.id),
                cliente: cliente,
                motos: motos[cliente.id],
                saldo: saldos[cliente.id],
                alPresionar: () => alAbrir(cliente),
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
                ref.read(clientesProvider.notifier).irAPagina(p),
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
            Icons.people_outline_rounded,
            size: 44,
            color: ColoresApp.textDisabled,
          ),
          const SizedBox(height: 14),
          Text(
            hayFiltro
                ? 'Ningún cliente coincide con el filtro'
                : 'Aún no hay clientes',
            style: TipografiaApp.subtitulo,
          ),
          const SizedBox(height: 6),
          Text(
            hayFiltro
                ? 'Prueba con otro término o quita el filtro de tipo.'
                : 'Crea el primero con "Nuevo cliente".',
            style: TipografiaApp.caption,
          ),
        ],
      ),
    );
  }
}
