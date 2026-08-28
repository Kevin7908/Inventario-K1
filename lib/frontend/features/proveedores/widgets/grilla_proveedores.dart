import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/proveedores/modelo/proveedor.dart';
import '../../../../core/resultado.dart';
import '../../../share/share.dart';
import '../provider/proveedores_provider.dart';
import 'tarjeta_proveedor.dart';

/// Grilla paginada de tarjetas de proveedor.
///
/// Vive aparte de la vista porque es la única parte de la pantalla que observa
/// los datos: así el encabezado, el buscador y los chips no se reconstruyen
/// cuando cambia la página.
class GrillaProveedores extends ConsumerStatefulWidget {
  const GrillaProveedores({super.key, required this.alEditar});

  final ValueChanged<Proveedor> alEditar;

  @override
  ConsumerState<GrillaProveedores> createState() => _GrillaProveedoresState();
}

class _GrillaProveedoresState extends ConsumerState<GrillaProveedores> {
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

  Future<void> _eliminar(Proveedor proveedor, int productos) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Eliminar "${proveedor.nombre}"?',
      mensaje: productos == 0
          ? 'Esta acción no se puede deshacer.'
          : 'Surte $productos producto${productos == 1 ? '' : 's'}, que '
                'quedará${productos == 1 ? '' : 'n'} sin proveedor asignado. '
                'Esta acción no se puede deshacer.',
    );
    if (confirmado != true || !mounted) return;

    final resultado = await ref
        .read(proveedoresProvider.notifier)
        .eliminar(proveedor.id!);
    if (!mounted) return;
    if (resultado case Fallo(:final mensaje)) _mostrarError(mensaje);
  }

  @override
  Widget build(BuildContext context) {
    final estadoAsync = ref.watch(proveedoresProvider);

    if (estadoAsync.isLoading && !estadoAsync.hasValue) {
      return const Center(
        child: CircularProgressIndicator(color: ColoresApp.goGreen),
      );
    }
    if (estadoAsync.hasError && !estadoAsync.hasValue) {
      return Center(
        child: Text(
          'Error al cargar proveedores: ${estadoAsync.error}',
          style: TipografiaApp.cuerpo,
        ),
      );
    }

    final proveedores = ref.watch(proveedoresFiltradosProvider);
    if (proveedores.isEmpty) {
      return _Vacio(
        hayFiltro: ref.watch(
          proveedoresProvider.select((s) => s.value?.hayFiltro ?? false),
        ),
      );
    }

    final conteo =
        ref.watch(conteoProductosPorProveedorProvider).value ?? const {};
    final pagina = ref.watch(
      proveedoresProvider.select((s) => (
            actual: s.value?.pagina ?? 0,
            total: s.value?.total ?? 0,
            paginas: s.value?.totalPaginas ?? 1,
            tamano: s.value?.tamanoPagina ?? 12,
          )),
    );

    return Column(
      children: [
        Expanded(child: _grilla(proveedores, conteo)),
        if (pagina.paginas > 1)
          PaginacionWidget(
            paginaActual: pagina.actual,
            totalPaginas: pagina.paginas,
            totalItems: pagina.total,
            itemsPorPagina: pagina.tamano,
            alCambiarPagina: (p) =>
                ref.read(proveedoresProvider.notifier).irAPagina(p),
          ),
      ],
    );
  }

  /// El mockup usa `minmax(330px, 1fr)`. El alto reserva sitio para las cuatro
  /// líneas del pie: NIT, contacto, teléfono, ciudad y el conteo de productos.
  Widget _grilla(List<Proveedor> proveedores, Map<int, int> conteo) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisExtent: 262,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: proveedores.length,
      itemBuilder: (context, i) {
        final proveedor = proveedores[i];
        final productos = conteo[proveedor.id] ?? 0;

        return TarjetaProveedor(
          key: ValueKey(proveedor.id),
          proveedor: proveedor,
          productos: productos,
          alPresionar: () => widget.alEditar(proveedor),
          alEditar: () => widget.alEditar(proveedor),
          alEliminar: () => _eliminar(proveedor, productos),
        );
      },
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.hayFiltro});

  final bool hayFiltro;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_shipping_outlined,
            size: 44,
            color: ColoresApp.textDisabled,
          ),
          const SizedBox(height: 14),
          Text(
            hayFiltro
                ? 'Ningún proveedor coincide con el filtro'
                : 'Aún no hay proveedores',
            style: TipografiaApp.subtitulo,
          ),
          const SizedBox(height: 6),
          Text(
            hayFiltro
                ? 'Prueba con otro término o quita el filtro de estado.'
                : 'Crea el primero con "Nuevo proveedor".',
            style: TipografiaApp.caption,
          ),
        ],
      ),
    );
  }
}
