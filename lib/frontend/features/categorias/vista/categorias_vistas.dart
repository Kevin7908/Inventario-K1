import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/categorias/modelo/categoria.dart';
import '../../../../core/resultado.dart';
import '../../../layout/encabezado_con_cuenta.dart';
import '../../../share/share.dart';
import '../detalle_categoria/vista/detalle_categoria_vista.dart';
import '../provider/categorias_provider.dart';
import '../widgets/dialogo_categorias_widget.dart';
import '../widgets/identidad_categoria.dart';

/// Pantalla de Categorías: catálogo en grilla de tarjetas.
///
/// Igual que Productos, hospeda la navegación interna del módulo —catálogo y
/// detalle— sin rutas globales. El alta y la edición sí van en diálogo: el
/// formulario son dos campos y una página completa sería desproporcionada.
class CategoriasVista extends ConsumerStatefulWidget {
  const CategoriasVista({super.key});

  @override
  ConsumerState<CategoriasVista> createState() => _CategoriasVistaState();
}

/// Vista activa dentro del módulo.
enum _Pantalla { lista, detalle }

class _CategoriasVistaState extends ConsumerState<CategoriasVista> {
  final _busquedaController = TextEditingController();
  final _focoBusqueda = FocusNode();
  Timer? _debounce;

  _Pantalla _pantalla = _Pantalla.lista;
  Categoria? _seleccionada;

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaController.dispose();
    _focoBusqueda.dispose();
    super.dispose();
  }

  void _alBuscar(String texto) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      ref.read(categoriasProvider.notifier).buscar(texto);
    });
  }

  void _verDetalle(Categoria categoria) => setState(() {
    _seleccionada = categoria;
    _pantalla = _Pantalla.detalle;
  });

  void _volverALista() => setState(() => _pantalla = _Pantalla.lista);

  @override
  Widget build(BuildContext context) {
    return switch (_pantalla) {
      _Pantalla.lista => _lista(),
      _Pantalla.detalle => DetalleCategoriaVista(
        categoria: _seleccionada!,
        alVolver: _volverALista,
      ),
    };
  }

  Widget _lista() {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _focoBusqueda.requestFocus(),
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _EncabezadoCategorias(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: BarraBusqueda(
                    controlador: _busquedaController,
                    focoTeclado: _focoBusqueda,
                    placeholder: 'Buscar categoría...',
                    alCambiar: _alBuscar,
                  ),
                ),
                const SizedBox(width: 20),
                BotonPrimario(
                  etiqueta: 'Nueva categoría',
                  icono: Icons.add,
                  alPresionar: () => DialogoCategoria.mostrar(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(child: _GrillaCategorias(alVerDetalle: _verDetalle)),
          ],
        ),
      ),
    );
  }
}

/// Encabezado con el conteo del catálogo.
class _EncabezadoCategorias extends ConsumerWidget {
  const _EncabezadoCategorias();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(
      categoriasProvider.select((s) => s.value?.total ?? 0),
    );

    return EncabezadoConCuenta(
      titulo: 'Categorías',
      subtitulo: total == 1
          ? 'Organización del catálogo de repuestos · 1 categoría'
          : 'Organización del catálogo de repuestos · $total categorías',
    );
  }
}

/// Grilla de tarjetas de categoría.
class _GrillaCategorias extends ConsumerStatefulWidget {
  const _GrillaCategorias({required this.alVerDetalle});

  final ValueChanged<Categoria> alVerDetalle;

  @override
  ConsumerState<_GrillaCategorias> createState() => _GrillaCategoriasState();
}

class _GrillaCategoriasState extends ConsumerState<_GrillaCategorias> {
  void _mostrarError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error,
          style: TipografiaApp.sobrePrimario(TipografiaApp.cuerpo),
        ),
        backgroundColor: ColoresApp.statusDanger,
      ),
    );
  }

  Future<void> _eliminar(Categoria categoria, int productos) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Eliminar "${categoria.nombre}"?',
      mensaje: productos == 0
          ? 'Esta acción no se puede deshacer.'
          : 'Tiene $productos producto${productos == 1 ? '' : 's'} asociado'
                '${productos == 1 ? '' : 's'}. Esta acción no se puede deshacer.',
    );
    if (confirmado != true || !mounted) return;

    final resultado = await ref
        .read(categoriasProvider.notifier)
        .eliminar(categoria.id!);
    if (!mounted) return;
    if (resultado case Fallo(:final mensaje)) _mostrarError(mensaje);
  }

  @override
  Widget build(BuildContext context) {
    final estadoAsync = ref.watch(categoriasProvider);

    if (estadoAsync.isLoading && !estadoAsync.hasValue) {
      return const Center(
        child: CircularProgressIndicator(color: ColoresApp.goGreen),
      );
    }
    if (estadoAsync.hasError && !estadoAsync.hasValue) {
      return Center(
        child: Text(
          'Error al cargar categorías: ${estadoAsync.error}',
          style: TipografiaApp.cuerpo,
        ),
      );
    }

    // Lista ya calculada por el provider derivado, no por el getter en build.
    final categorias = ref.watch(categoriasFiltradasProvider);
    if (categorias.isEmpty) {
      return _Vacio(busqueda: ref.watch(busquedaCategoriasProvider));
    }

    final conteo =
        ref.watch(conteoProductosPorCategoriaProvider).value ?? const {};
    final pagina = ref.watch(
      categoriasProvider.select((s) => (
            actual: s.value?.pagina ?? 0,
            total: s.value?.total ?? 0,
            paginas: s.value?.totalPaginas ?? 1,
            tamano: s.value?.tamanoPagina ?? 24,
          )),
    );

    return Column(
      children: [
        Expanded(child: _grilla(categorias, conteo)),
        if (pagina.paginas > 1)
          PaginacionWidget(
            paginaActual: pagina.actual,
            totalPaginas: pagina.paginas,
            totalItems: pagina.total,
            itemsPorPagina: pagina.tamano,
            alCambiarPagina: (p) =>
                ref.read(categoriasProvider.notifier).irAPagina(p),
          ),
      ],
    );
  }

  /// El mockup usa `minmax(220px, 1fr)`: columnas que nunca bajan de ~220.
  /// El alto reserva sitio para títulos de dos líneas.
  Widget _grilla(List<Categoria> categorias, Map<int, int> conteo) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisExtent: 180,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: categorias.length,
      itemBuilder: (context, i) {
        final categoria = categorias[i];
        final productos = conteo[categoria.id] ?? 0;

        return TarjetaCatalogo(
          key: ValueKey(categoria.id),
          orientacion: OrientacionTarjeta.vertical,
          marcador: MarcadorIdentidad(
            inicial: inicialDe(categoria.nombre),
            color: IdentidadCategoria.color,
            lado: 50,
            radio: 14,
          ),
          titulo: categoria.nombre,
          subtitulo: productos == 1 ? '1 producto' : '$productos productos',
          alPresionar: () => widget.alVerDetalle(categoria),
          acciones: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BotonIcono(
                icono: Icons.edit_outlined,
                tooltip: 'Editar',
                alPresionar: () => DialogoCategoria.mostrar(
                  context,
                  categoriaAEditar: categoria,
                ),
              ),
              BotonIcono(
                icono: Icons.delete_outline_rounded,
                tooltip: 'Eliminar',
                color: ColoresApp.statusDanger,
                alPresionar: () => _eliminar(categoria, productos),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.busqueda});

  final String busqueda;

  @override
  Widget build(BuildContext context) {
    final hayFiltro = busqueda.trim().isNotEmpty;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.layers_outlined,
            size: 44,
            color: ColoresApp.textDisabled,
          ),
          const SizedBox(height: 14),
          Text(
            hayFiltro
                ? 'Sin resultados para "$busqueda"'
                : 'Aún no hay categorías',
            style: TipografiaApp.subtitulo,
          ),
          const SizedBox(height: 6),
          Text(
            hayFiltro
                ? 'Prueba con otro término de búsqueda.'
                : 'Crea la primera con "Nueva categoría".',
            style: TipografiaApp.caption,
          ),
        ],
      ),
    );
  }
}
