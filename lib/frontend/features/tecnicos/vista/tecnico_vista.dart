import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/botones/dialogo_confirmar_eliminar_widget.dart';
import '../../../share/widgets/input/barra_busqueda_widget.dart';
import '../../../share/widgets/output/estado_error_widget.dart';
import '../../../share/widgets/output/estado_vacio_widget.dart';
import '../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../../share/widgets/top_bar_widget.dart';
import '../provider/tecnico_provider.dart';
import '../widgets/dialogo_tecnico_widget.dart';
import '../widgets/tarjeta_tecnico_widget.dart';

class TecnicosVista extends ConsumerStatefulWidget {
  const TecnicosVista({super.key});

  @override
  ConsumerState<TecnicosVista> createState() => _TecnicosVistaState();
}

class _TecnicosVistaState extends ConsumerState<TecnicosVista> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(busquedaTecnicoProvider.notifier).state = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.bgContent,
      body: Column(
        children: [
          TopBarConBoton(
            titulo: 'Técnicos',
            etiquetaBoton: 'Agregar',
            alPresionarBoton: () => DialogoTecnico.mostrar(context),
          ),

          BarraBusquedaWidget(
            placeholder: 'Buscar técnico o cédula...',
            alCambiar: _onSearchChanged,
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
    final asyncTecnicos = ref.watch(tecnicosFiltradosProvider);
    final busqueda = ref.watch(busquedaTecnicoProvider);

    return asyncTecnicos.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: ColoresApp.primary),
      ),
      error: (e, _) => EstadoErrorWidget(
        mensaje: e.toString(),
        alReintentar: () => ref.invalidate(tecnicosProvider),
      ),
      data: (tecnicos) {
        if (tecnicos.isEmpty) {
          return EstadoVacioWidget(
            icono: Icons.engineering_outlined,
            textoSinDatos: 'Sin técnicos aún',
            textoSinResultados: 'No hay técnicos que coincidan.',
            textoCTA: 'Crea tu primer técnico presionando "Agregar".',
            hayFiltro: busqueda.isNotEmpty,
          );
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: _ContadorTecnicos(total: tecnicos.length),
              ),
            ),
            _SliverGrillaTecnicos(tecnicos: tecnicos),
          ],
        );
      },
    );
  }
}

class _ContadorTecnicos extends StatelessWidget {
  const _ContadorTecnicos({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$total TÉCNICO${total == 1 ? '' : 'S'}',
      style: const TextStyle(
        color: ColoresApp.textLight,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _SliverGrillaTecnicos extends ConsumerWidget {
  const _SliverGrillaTecnicos({required this.tecnicos});

  final List tecnicos; // List<Tecnico>

  static const double _maxAnchoCelda = 300.0;
  static const double _espaciado = 16.0;
  static const double _alturaCelda = 260.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final tecnico = tecnicos[i];
            return TarjetaTecnicoWidget(
              key: ValueKey(tecnico.id),
              tecnico: tecnico,
              alEditar: () => DialogoTecnico.mostrar(
                context,
                tecnicoAEditar: tecnico,
              ),
              alEliminar: () => DialogoConfirmarEliminar.mostrar(
                context: context,
                nombreElemento: tecnico.nombreCompleto,
                tipoElemento: 'técnico',
                onConfirmar: () async {
                  final error = await ref
                      .read(tecnicosProvider.notifier)
                      .eliminar(tecnico.id!);
                  if (error != null && context.mounted) {
                    SnackBarMensaje.error(context, error);
                  }
                },
              ),
            );
          },
          childCount: tecnicos.length,
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: _maxAnchoCelda,
          crossAxisSpacing: _espaciado,
          mainAxisSpacing: _espaciado,
          mainAxisExtent: _alturaCelda,
        ),
      ),
    );
  }
}