import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/unidades_medida/modelo/unidad_medida.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/dialogos/dialogo_confirmar_eliminar_widget.dart';
import '../../../share/widgets/input/barra_busqueda_dropdown.dart';
import '../../../share/widgets/output/estado_error_widget.dart';
import '../../../share/widgets/output/estado_vacio_widget.dart';
import '../../../share/widgets/top_bar_widget.dart';
import '../provider/unidades_medida_provider.dart';
import '../widgets/dialogo_unidad_medida_widget.dart';
import '../widgets/fila_unidad_medida_widget.dart';

class UnidadesMedidaVista extends StatelessWidget {
  const UnidadesMedidaVista({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.bgContent,
      body: Column(
        children: [
          TopBarConBoton(
            titulo: 'Unidades de Medida',
            etiquetaBoton: 'Agregar',
            alPresionarBoton: () => DialogoUnidadMedida.mostrar(context),
          ),
          const Expanded(child: _CuerpoLista()),
        ],
      ),
    );
  }
}

class _CuerpoLista extends ConsumerWidget {
  const _CuerpoLista();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estadoAsync = ref.watch(unidadesMedidaProvider);

    return estadoAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: ColoresApp.primary),
      ),
      error: (e, _) => EstadoErrorWidget(
        mensaje: 'Error al cargar unidades: $e',
        alReintentar: () => ref.invalidate(unidadesMedidaProvider),
      ),
      data: (estado) {
        final unidades = estado.filtradas;

        if (unidades.isEmpty) {
          return EstadoVacioWidget(
            icono: Icons.straighten_outlined,
            textoSinDatos: 'Sin unidades de medida aún',
            textoSinResultados: 'No hay unidades que coincidan.',
            textoCTA:
                'Crea tu primera unidad de medida presionando "Agregar".',
            hayFiltro:
                estado.textoBusqueda.isNotEmpty || estado.filtroTipo != 'todos',
          );
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BarraBusquedaDropdown(
                      placeholder: 'Buscar unidad...',
                      alBuscar: (q) =>
                          ref.read(unidadesMedidaProvider.notifier).buscar(q),
                      valorFiltro: estado.filtroTipo,
                      opcionesFiltro: [
                        'todos',
                        ...UnidadMedida.tiposDisponibles,
                      ],
                      alCambiarFiltro: (v) => ref
                          .read(unidadesMedidaProvider.notifier)
                          .filtrarPorTipo(v ?? 'todos'),
                    ),
                    const SizedBox(height: 14),
                    _ContadorUnidades(total: unidades.length),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              sliver: SliverList.separated(
                itemCount: unidades.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final unidad = unidades[i];
                  return FilaUnidadMedidaWidget(
                    key: ValueKey(unidad.id),
                    unidad: unidad,
                    alEditar: () => DialogoUnidadMedida.mostrar(
                      context,
                      unidadAEditar: unidad,
                    ),
                    alEliminar: () => DialogoConfirmarEliminar.mostrar(
                      context: context,
                      nombreElemento: unidad.nombre,
                      tipoElemento: 'unidad de medida',
                      onConfirmar: () => ref
                          .read(unidadesMedidaProvider.notifier)
                          .eliminar(unidad.id!),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ContadorUnidades extends StatelessWidget {
  const _ContadorUnidades({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$total UNIDAD${total == 1 ? '' : 'ES'}',
      style: const TextStyle(
        color: ColoresApp.textLight,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
      ),
    );
  }
}
