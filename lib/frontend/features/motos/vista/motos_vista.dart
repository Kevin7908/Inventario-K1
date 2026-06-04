import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/motos/modelo/moto.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/dialogos/dialogo_confirmar_eliminar_widget.dart';
import '../../../share/widgets/input/barra_busqueda_widget.dart';
import '../../../share/widgets/output/estado_error_widget.dart';
import '../../../share/widgets/output/estado_vacio_widget.dart';
import '../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../../share/widgets/top_bar_widget.dart';
import '../provider/motos_provider.dart';
import '../widgets/dialogo_motos.dart';
import '../widgets/tarjeta_moto_widget.dart';

class MotosVista extends ConsumerWidget {
  const MotosVista({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(motosProvider);

    return Scaffold(
      backgroundColor: ColoresApp.bgContent,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: TopBarConBoton(
              titulo: 'Motos',
              etiquetaBoton: 'Agregar',
              alPresionarBoton: () => DialogoMoto.mostrar(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: BarraBusquedaWidget(
                placeholder: 'Buscar por marca, modelo, placa, cliente…',
                alCambiar: (v) =>
                    ref.read(motosProvider.notifier).buscar(v),
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
                alReintentar: () => ref.invalidate(motosProvider),
              ),
            ),
            data: (estado) {
              final lista = estado.filtrados;
              if (lista.isEmpty) {
                return SliverFillRemaining(
                  child: EstadoVacioWidget(
                    textoCTA: '',
                    icono: Icons.two_wheeler_outlined,
                    textoSinDatos: estado.textoBusqueda.isNotEmpty
                        ? 'Sin resultados'
                        : 'Sin motos aún',
                    textoSinResultados: estado.textoBusqueda.isNotEmpty
                        ? 'Prueba con otro término de búsqueda'
                        : 'Agrega tu primera moto tocando "Agregar"',
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
                    childAspectRatio: 0.78,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final moto = lista[i];
                      return TarjetaMotoWidget(
                        key: ValueKey(moto.id),
                        moto: moto,
                        alEditar: () =>
                            DialogoMoto.mostrar(context, moto: moto),
                        alEliminar: () =>
                            _confirmarEliminar(context, ref, moto),
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

  void _confirmarEliminar(BuildContext context, WidgetRef ref, Moto moto) {
    DialogoConfirmarEliminar.mostrar(
      context: context,
      nombreElemento: '${moto.marca} ${moto.modelo}',
      tipoElemento: 'moto',
      onConfirmar: () async {
        final error =
            await ref.read(motosProvider.notifier).eliminar(moto.id);
        if (!context.mounted) return;
        if (error != null) {
          SnackBarMensaje.error(context, error);
        } else {
          SnackBarMensaje.success(context, 'Moto eliminada.');
        }
      },
    );
  }
}
