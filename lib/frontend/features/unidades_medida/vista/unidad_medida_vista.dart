// frontend/features/unidades_medida/vistas/unidades_medida_vista.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../backend/features/unidades_medida/modelo/unidad_medida.dart';
import '../../../../backend/share/database/locator.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/botones/dialogo_confirmar_eliminar_widget.dart';
import '../../../share/widgets/output/estado_error_widget.dart';
import '../../../share/widgets/output/estado_vacio_widget.dart';
import '../../../share/widgets/input/barra_busqueda_dropdown.dart';
import '../../../share/widgets/top_bar_widget.dart';
import '../view_model/unidad_medida_view_model.dart';
import '../widgets/dialogo_unidad_medida_widget.dart';
import '../widgets/fila_unidad_medida_widget.dart';

/// Vista de Unidades de Medida — misma estructura que CategoriasVista.
///
/// Patrón aplicado:
/// ─────────────────
/// - Consumer aislado en _CuerpoLista (no rebuilds en Scaffold).
/// - CustomScrollView + SliverList.separated (lazy, sin shrinkWrap).
/// - SliverToBoxAdapter para el encabezado (búsqueda + dropdown + contador).
/// - ViewModel instanciado en initState y destruido en dispose.
class UnidadesMedidaVista extends StatefulWidget {
  const UnidadesMedidaVista({super.key});

  @override
  State<UnidadesMedidaVista> createState() => _UnidadesMedidaVistaState();
}

class _UnidadesMedidaVistaState extends State<UnidadesMedidaVista> {
  late final UnidadesMedidaViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = locator<UnidadesMedidaViewModel>();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UnidadesMedidaViewModel>.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: ColoresApp.bgContent,
        body: Column(
          children: [
            TopBarConBoton(
              titulo: 'Unidades de Medida',
              etiquetaBoton: 'Agregar',
              alPresionarBoton: () =>
                  DialogoUnidadMedida.mostrar(context, viewModel: _vm),
            ),
            const Expanded(child: _CuerpoLista()),
          ],
        ),
      ),
    );
  }
}

// Cuerpo principal (Consumer único)
class _CuerpoLista extends StatelessWidget {
  const _CuerpoLista();

  @override
  Widget build(BuildContext context) {
    return Consumer<UnidadesMedidaViewModel>(
      builder: (context, vm, _) {
        // Carga
        if (vm.estaCargando) {
          return const Center(
            child: CircularProgressIndicator(color: ColoresApp.primary),
          );
        }

        // Error
        if (vm.estado == EstadoUnidadesMedida.error) {
          return EstadoErrorWidget(
            mensaje: vm.mensajeError ?? 'Error desconocido',
            alReintentar: vm.cargarUnidades,
          );
        }

        // Vacío 
        if (vm.unidades.isEmpty) {
          return EstadoVacioWidget(
            icono: Icons.straighten_outlined,
            textoSinDatos: 'Sin unidades de medida aún',
            textoSinResultados: 'No hay unidades que coincidan.',
            textoCTA: 'Crea tu primera unidad de medida presionando "Agregar".',
            hayFiltro:
                vm.consultaBusqueda.isNotEmpty ||
                (vm.filtroTipo != 'todos'), //vm.filtroTipo != null &&
          );
        }

        // Lista
        return CustomScrollView(
          slivers: [
            // Encabezado: barra de búsqueda + dropdown + contador
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BarraBusquedaDropdown(
                      placeholder: 'Buscar unidad...',
                      alBuscar: vm.buscar,
                      valorFiltro: vm.filtroTipo,
                      opcionesFiltro: [
                        'todos',
                        ...UnidadMedida.tiposDisponibles,
                      ],
                      alCambiarFiltro: (v) => vm.filtrarPorTipo(v ?? 'todos'),
                    ),
                    const SizedBox(height: 14),
                    _ContadorUnidades(total: vm.unidades.length),
                  ],
                ),
              ),
            ),

            // Lista lazy de filas
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              sliver: SliverList.separated(
                itemCount: vm.unidades.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final unidad = vm.unidades[i];
                  return FilaUnidadMedidaWidget(
                    key: ValueKey(unidad.id),
                    unidad: unidad,
                    alEditar: () => DialogoUnidadMedida.mostrar(
                      context,
                      unidadAEditar: unidad,
                      viewModel: vm,
                    ),
                    alEliminar: () => DialogoConfirmarEliminar.mostrar(
                      context: context,
                      nombreElemento: unidad.nombre,
                      tipoElemento: 'unidad de medida',
                      onConfirmar: () => vm.eliminarUnidad(unidad.id!),
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

// Contador

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
