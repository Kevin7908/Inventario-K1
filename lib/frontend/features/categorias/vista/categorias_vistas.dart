import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/dialogos/dialogo_confirmar_eliminar_widget.dart';
import '../../../share/widgets/input/barra_busqueda_widget.dart';
import '../../../share/widgets/output/estado_error_widget.dart';
import '../../../share/widgets/output/estado_vacio_widget.dart';
import '../../../share/widgets/top_bar_widget.dart';
import '../detalle_categoria/vista/detalle_categoria_vista.dart';
import '../provider/categorias_provider.dart';
import '../widgets/dialogo_categorias_widget.dart';
import '../widgets/fila_categoria_widget.dart';

class CategoriasVista extends ConsumerStatefulWidget {
  const CategoriasVista({super.key});

  @override
  ConsumerState<CategoriasVista> createState() => _CategoriasVistaState();
}

class _CategoriasVistaState extends ConsumerState<CategoriasVista> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      ref.read(categoriasProvider.notifier).buscar(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.bgContent,
      body: Column(
        children: [
          TopBarConBoton(
            titulo: 'Categorías',
            etiquetaBoton: 'Agregar',
            alPresionarBoton: () => DialogoCategoria.mostrar(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: BarraBusquedaWidget(
              placeholder: 'Buscar categoría...',
              alCambiar: _onSearchChanged,
            ),
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
    final estadoAsync = ref.watch(categoriasProvider);

    return estadoAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: ColoresApp.primary),
      ),
      error: (e, _) => EstadoErrorWidget(
        mensaje: 'Error al cargar categorías: $e',
        alReintentar: () => ref.invalidate(categoriasProvider),
      ),
      data: (estado) {
        final cats = estado.filtradas;

        if (cats.isEmpty) {
          return EstadoVacioWidget(
            icono: Icons.category_outlined,
            textoSinDatos: 'Sin categorías aún',
            textoSinResultados: 'No hay categorías que coincidan.',
            textoCTA: 'Crea tu primera categoría presionando "Agregar".',
            hayFiltro: estado.textoBusqueda.isNotEmpty,
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
                    const SizedBox(height: 14),
                    _ContadorCategorias(total: cats.length),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              sliver: SliverList.separated(
                itemCount: cats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final cat = cats[i];
                  return FilaCategoriaWidget(
                    key: ValueKey(cat.id),
                    categoria: cat,
                    alVerDetalle: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DetalleCategoriaVista(categoria: cat),
                      ),
                    ),
                    alEditar: () => DialogoCategoria.mostrar(
                      context,
                      categoriaAEditar: cat,
                    ),
                    alEliminar: () => DialogoConfirmarEliminar.mostrar(
                      context: context,
                      nombreElemento: cat.nombre,
                      tipoElemento: 'categoría',
                      onConfirmar: () =>
                          ref.read(categoriasProvider.notifier).eliminar(cat.id!),
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

class _ContadorCategorias extends StatelessWidget {
  const _ContadorCategorias({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${total.toString().toUpperCase()} CATEGORÍA${total == 1 ? '' : 'S'}',
      style: const TextStyle(
        color: ColoresApp.textLight,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
      ),
    );
  }
}
