import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../share/temas/colores_app.dart';
import '../../../../share/widgets/input/barra_busqueda_widget.dart';
import '../../../../share/widgets/output/chip_filtro_widget.dart';
import '../../../../share/widgets/output/estado_error_widget.dart';
import '../../../../share/widgets/output/estado_vacio_widget.dart';
import '../../../../share/widgets/top_bar_widget.dart';
import '../provider/servicios_provider.dart';
import '../widgets/dialogo_servicios.dart';
import '../widgets/servicio_carta_widget.dart';

class ServiciosVista extends ConsumerStatefulWidget {
  const ServiciosVista({super.key});

  @override
  ConsumerState<ServiciosVista> createState() => _ServiciosVistaState();
}

class _ServiciosVistaState extends ConsumerState<ServiciosVista> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      ref.read(busquedaServiciosProvider.notifier).state = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.bgContent,
      body: Column(
        children: [
          TopBarConBoton(
            titulo: 'Servicios',
            etiquetaBoton: 'Agregar',
            alPresionarBoton: () => DialogoServicio.mostrar(context),
          ),
          // Barra busqueda + chips filtro
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: BarraBusquedaWidget(
                    placeholder: 'Buscar servicio...',
                    alCambiar: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 12),
                ChipFiltro(
                  etiqueta: 'Activos',
                  seleccionado: ref.watch(soloActivosServiciosProvider),
                  alPresionar: () =>
                      ref.read(soloActivosServiciosProvider.notifier).state = true,
                ),
                const SizedBox(width: 8),
                ChipFiltro(
                  etiqueta: 'Todos',
                  seleccionado: !ref.watch(soloActivosServiciosProvider),
                  alPresionar: () =>
                      ref.read(soloActivosServiciosProvider.notifier).state = false,
                ),
              ],
            ),
          ),
          const Expanded(child: _CuerpoGrid()),
        ],
      ),
    );
  }
}

// Cuerpo aislado para evitar reconstrucciones globales
class _CuerpoGrid extends ConsumerWidget {
  const _CuerpoGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFiltrados = ref.watch(serviciosFiltradosProvider);
    final query = ref.watch(busquedaServiciosProvider);

    return asyncFiltrados.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: ColoresApp.primary),
      ),
      error: (err, _) => EstadoErrorWidget(
        mensaje: err.toString(),
        alReintentar: () => ref.invalidate(serviciosProvider),
      ),
      data: (lista) {
        if (lista.isEmpty) {
          return EstadoVacioWidget(
            icono: Icons.home_repair_service_outlined,
            textoSinDatos: 'Sin servicios aun',
            textoSinResultados: 'No hay servicios que coincidan con la busqueda.',
            textoCTA: 'Crea tu primer servicio presionando Agregar.',
            hayFiltro: query.isNotEmpty,
          );
        }

        return CustomScrollView(
          slivers: [
            // Contador
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: _ContadorServicios(total: lista.length),
              ),
            ),

            // Grid de tarjetas
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  mainAxisExtent: 185,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => ServicioCartaWidget(
                    key: ValueKey(lista[i].id),
                    servicio: lista[i],
                  ),
                  childCount: lista.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ContadorServicios extends StatelessWidget {
  const _ContadorServicios({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$total SERVICIO${total == 1 ? '' : 'S'}',
      style: const TextStyle(
        color: ColoresApp.textLight,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
      ),
    );
  }
}