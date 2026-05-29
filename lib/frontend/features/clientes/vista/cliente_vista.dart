import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/dialogos/dialogo_confirmar_eliminar_widget.dart';
import '../../../share/widgets/input/barra_busqueda_widget.dart';
import '../../../share/widgets/output/estado_error_widget.dart';
import '../../../share/widgets/output/estado_vacio_widget.dart';
import '../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../../share/widgets/top_bar_widget.dart';
import '../provider/cliente_provider.dart';
import '../widget/dialogo_cliente_widget.dart';
import '../widget/tarjeta_cliente_widget.dart';

class ClientesVista extends ConsumerWidget {
  const ClientesVista({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(clientesProvider);

    return Scaffold(
      backgroundColor: ColoresApp.bgContent,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: TopBarConBoton(
              titulo: 'Clientes',
              etiquetaBoton: 'Agregar',
              alPresionarBoton: () => DialogoCliente.mostrar(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: BarraBusquedaWidget(
                placeholder: 'Buscar por nombre, cédula, ciudad…',
                alCambiar: (v) =>
                    ref.read(clientesProvider.notifier).buscar(v),
              ),
            ),
          ),
          asyncState.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: ColoresApp.primary),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: EstadoErrorWidget(
                mensaje: e.toString(),
                alReintentar: () => ref.invalidate(clientesProvider),
              ),
            ),
            data: (estado) {
              final lista = estado.filtrados;
              if (lista.isEmpty) {
                return SliverFillRemaining(
                  child: EstadoVacioWidget(
                    textoCTA: '',
                    icono: Icons.people_outline,
                    textoSinDatos: estado.textoBusqueda.isNotEmpty
                        ? 'Sin resultados'
                        : 'Sin clientes aún',
                    textoSinResultados: estado.textoBusqueda.isNotEmpty
                        ? 'Prueba con otro término de búsqueda'
                        : 'Agrega tu primer cliente tocando "Agregar"',
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final cliente = lista[i];
                      return TarjetaClienteWidget(
                        key: ValueKey(cliente.id),
                        cliente: cliente,
                        alEditar: () =>
                            DialogoCliente.mostrar(context, cliente: cliente),
                        alEliminar: () =>
                            _confirmarEliminar(context, ref, cliente),
                      );
                    },
                    childCount: lista.length,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  void _confirmarEliminar(
      BuildContext context, WidgetRef ref, Cliente cliente) {
    DialogoConfirmarEliminar.mostrar(
      context: context,
      nombreElemento: cliente.nombreCompleto,
      tipoElemento: 'cliente',
      onConfirmar: () async {
        final error =
            await ref.read(clientesProvider.notifier).eliminar(cliente.id);
        if (!context.mounted) return;
        if (error != null) {
          SnackBarMensaje.error(context, error);
        } else {
          SnackBarMensaje.success(context, 'Cliente eliminado.');
        }
      },
    );
  }
}
