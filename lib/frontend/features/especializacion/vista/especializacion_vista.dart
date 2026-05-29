// frontend/features/especializaciones/vistas/especializaciones_vista.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/dialogos/dialogo_confirmar_eliminar_widget.dart';
import '../../../share/widgets/input/barra_busqueda_widget.dart';
import '../../../share/widgets/output/estado_error_widget.dart';
import '../../../share/widgets/output/estado_vacio_widget.dart';
import '../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../../share/widgets/top_bar_widget.dart';
import '../provider/especializacion_provider.dart';
import '../widgets/dialogo_especializacion.dart';
import '../widgets/fila_especializacion_widget.dart';

class EspecializacionesVista extends ConsumerStatefulWidget {
  const EspecializacionesVista({super.key});

  @override
  ConsumerState<EspecializacionesVista> createState() =>
      _EspecializacionesVistaState();
}

class _EspecializacionesVistaState
    extends ConsumerState<EspecializacionesVista> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      ref.read(busquedaEspecializacionProvider.notifier).state = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.bgContent,
      body: Column(
        children: [
          // TopBar — solo se reconstruye si cambia el scaffold 
          TopBarConBoton(
            titulo: 'Especializaciones',
            etiquetaBoton: 'Agregar',
            alPresionarBoton: () =>
                DialogoEspecializacion.mostrar(context),
          ),

          // Barra de búsqueda 
          BarraBusquedaWidget(
            placeholder: 'Buscar especialización...',
            alCambiar: _onSearchChanged,
          ),

          // Cuerpo reactivo 
          const Expanded(child: _CuerpoLista()),
        ],
      ),
    );
  }
}

// Cuerpo — Consumer aislado del Scaffold para evitar reconstrucciones globales
class _CuerpoLista extends ConsumerWidget {
  const _CuerpoLista();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFiltradas = ref.watch(especializacionesFiltradasProvider);
    final query = ref.watch(busquedaEspecializacionProvider);

    return asyncFiltradas.when(
      // Loading 
      loading: () => const Center(
        child: CircularProgressIndicator(color: ColoresApp.primary),
      ),

      // Error 
      error: (err, _) => EstadoErrorWidget(
        mensaje: err.toString(),
        alReintentar: () =>
            ref.invalidate(especializacionesProvider),
      ),

      // Data 
      data: (lista) {
        if (lista.isEmpty) {
          return EstadoVacioWidget(
            icono: Icons.build_circle_outlined,
            textoSinDatos: 'Sin especializaciones aún',
            textoSinResultados:
                'No hay áreas que coincidan con "$query".',
            textoCTA:
                'Crea tu primera especialización presionando "Agregar".',
            hayFiltro: query.isNotEmpty,
          );
        }

        return CustomScrollView(
          slivers: [
            // Contador + separador superior
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: _ContadorEspecializaciones(total: lista.length),
              ),
            ),

            // Lista de filas
            SliverList.builder(
              itemCount: lista.length,
              itemBuilder: (context, i) {
                final e = lista[i];
                return FilaEspecializacion(
                  key: ValueKey(e.id),
                  especializacion: e,
                  indice: i,
                  alEditar: () => DialogoEspecializacion.mostrar(
                    context,
                    especializacionAEditar: e,
                  ),
                  alEliminar: () => DialogoConfirmarEliminar.mostrar(
                    context: context,
                    nombreElemento: e.nombre,
                    tipoElemento: 'especialización',
                    onConfirmar: () {
                      // leemos ref desde el Consumer padre mediante closure
                      final notif = ProviderScope.containerOf(context)
                          .read(especializacionesProvider.notifier);
                      notif.eliminar(e.id).then((error) {
                        if (!context.mounted) return;
                        if (error != null) {
                          SnackBarMensaje.error(context, error);
                        } else {
                          SnackBarMensaje.success(
                            context,
                            '"${e.nombre}" eliminado correctamente.',
                          );
                        }
                      });
                    },
                  ),
                );
              },
            ),

            // Padding final para no quedar tapado por la nav bar
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        );
      },
    );
  }
}

// Contador
class _ContadorEspecializaciones extends StatelessWidget {
  const _ContadorEspecializaciones({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$total ESPECIALIZACIÓN${total == 1 ? '' : 'ES'}',
      style: const TextStyle(
        color: ColoresApp.textLight,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
      ),
    );
  }
}