import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../backend/share/database/locator.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/botones/dialogo_confirmar_eliminar_widget.dart';
import '../../../share/widgets/input/barra_busqueda_widget.dart';
import '../../../share/widgets/output/estado_error_widget.dart';
import '../../../share/widgets/output/estado_vacio_widget.dart';
import '../../../share/widgets/top_bar_widget.dart';
import '../view_model/categorias_view_model.dart';
import '../widgets/dialogo_categorias_widget.dart';
import '../widgets/fila_categoria_widget.dart';

/// Vista de Categorías — rediseñada y optimizada.
///
/// Cambios respecto a la versión anterior:
/// ─────────────────────────────────────────
/// 1. **GridView → ListView.builder**: elimina el double-layout-pass que
///    causaba `shrinkWrap: true` + `NeverScrollableScrollPhysics` dentro de
///    un `SingleChildScrollView`. El `ListView.builder` solo construye los
///    ítems visibles (lazy) y no necesita calcular el tamaño total.
///
/// 2. **CustomScrollView + SliverList**: el encabezado (barra de búsqueda +
///    contador) se integra como `SliverToBoxAdapter`, permitiendo que TODO el
///    contenido comparta un único `Scrollable`. Antes había dos Scrollables
///    anidados, lo que duplicaba el trabajo del engine.
///
/// 3. **Separador reutilizable const**: `SizedBox` con altura fija en vez de
///    `Divider` para separar ítems, evitando un widget extra con pintura propia.
///
/// 4. **Estado local aislado**: el ViewModel sigue en `initState`/`dispose`
///    (patrón correcto con get_it factory). El `ChangeNotifierProvider.value`
///    no re-crea el provider en cada rebuild del padre.
class CategoriasVista extends StatefulWidget {
  const CategoriasVista({super.key});

  @override
  State<CategoriasVista> createState() => _CategoriasVistaState();
}

class _CategoriasVistaState extends State<CategoriasVista> {
  late final CategoriasViewModel _vm;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _vm = locator<CategoriasViewModel>();
  }

  @override
  void dispose() {
    _vm.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      _vm.buscar(query); // Solo se ejecuta tras 1000ms de silencio
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CategoriasViewModel>.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: ColoresApp.bgContent,
        body: Column(
          children: [
            TopBarConBoton(
              titulo: 'Categorías',
              etiquetaBoton: 'Agregar',
              alPresionarBoton: () =>
                  DialogoCategoria.mostrar(context, viewModel: _vm),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: BarraBusquedaWidget(
                placeholder: 'Buscar categoría...',
                alCambiar:
                    _onSearchChanged, // Usamos nuestra función con debounce
              ),
            ),
            const Expanded(child: _CuerpoLista()),
          ],
        ),
      ),
    );
  }
}

// ─── Cuerpo principal (Consumer único) ───────────────────────────────────────

/// Separa el Consumer en su propio widget para que los rebuilds por el
/// ViewModel no afecten a [CategoriasVista] ni al [Scaffold].
class _CuerpoLista extends StatelessWidget {
  const _CuerpoLista();

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoriasViewModel>(
      builder: (context, vm, _) {
        // ── Carga ────────────────────────────────────────────────────────
        if (vm.estaCargando) {
          return const Center(
            child: CircularProgressIndicator(color: ColoresApp.primary),
          );
        }

        // ── Error ────────────────────────────────────────────────────────
        if (vm.estado == EstadoCategorias.error) {
          return EstadoErrorWidget(
            mensaje: vm.mensajeError ?? 'Error desconocido',
            alReintentar: vm.cargarCategorias,
          );
        }

        // ── Vacío ────────────────────────────────────────────────────────
        if (vm.categorias.isEmpty) {
          return EstadoVacioWidget(
            icono: Icons.category_outlined,
            textoSinDatos: 'Sin categorías aún',
            textoSinResultados: 'No hay categorías que coincidan.',
            textoCTA: 'Crea tu primera categoría presionando "Agregar".',
            hayFiltro: vm.consultaBusqueda.isNotEmpty,
          );
        }

        // ── Lista ────────────────────────────────────────────────────────
        return CustomScrollView(
          slivers: [
            // Barra de búsqueda + contador sticky al tope
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    _ContadorCategorias(total: vm.categorias.length),
                  ],
                ),
              ),
            ),

            // Lista lazy de ítems
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              sliver: SliverList.separated(
                itemCount: vm.categorias.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final cat = vm.categorias[i];
                  return FilaCategoriaWidget(
                    // key estable evita que Flutter recicle el widget
                    // de una categoría con los datos de otra al filtrar.
                    key: ValueKey(cat.id),
                    categoria: cat,
                    alEditar: () => DialogoCategoria.mostrar(
                      context,
                      categoriaAEditar: cat,
                      viewModel: vm,
                    ),
                    alEliminar: () => DialogoConfirmarEliminar.mostrar(
                      context: context,
                      nombreElemento: cat.nombre,
                      tipoElemento: 'categoría',
                      onConfirmar: () => vm.eliminarCategoria(cat.id!),
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

// Contador de categorías

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
