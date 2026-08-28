import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/especializacion/modelo/especializacion.dart';
import '../../../../backend/features/tecnicos/modelo/tecnico.dart';
import '../../../../core/resultado.dart';
import '../../../share/share.dart';
import '../../especializacion/provider/especializacion_provider.dart';
import '../provider/tecnico_provider.dart';
import 'tarjeta_tecnico.dart';

/// Grilla paginada de tarjetas de técnico.
///
/// Vive aparte de la vista porque es la única parte de la pantalla que observa
/// los datos: así el encabezado, el buscador y los chips no se reconstruyen
/// cuando cambia la página.
class GrillaTecnicos extends ConsumerStatefulWidget {
  const GrillaTecnicos({super.key, required this.alEditar});

  final ValueChanged<Tecnico> alEditar;

  @override
  ConsumerState<GrillaTecnicos> createState() => _GrillaTecnicosState();
}

class _GrillaTecnicosState extends ConsumerState<GrillaTecnicos> {
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

  Future<void> _eliminar(Tecnico tecnico) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Eliminar a "${tecnico.nombreCompleto}"?',
      mensaje: 'Esta acción no se puede deshacer.',
    );
    if (confirmado != true || !mounted) return;

    final resultado =
        await ref.read(tecnicosProvider.notifier).eliminar(tecnico.id!);
    if (!mounted) return;
    if (resultado case Fallo(:final mensaje)) _mostrarError(mensaje);
  }

  @override
  Widget build(BuildContext context) {
    final estadoAsync = ref.watch(tecnicosProvider);

    if (estadoAsync.isLoading && !estadoAsync.hasValue) {
      return const Center(
        child: CircularProgressIndicator(color: ColoresApp.goGreen),
      );
    }
    if (estadoAsync.hasError && !estadoAsync.hasValue) {
      return Center(
        child: Text(
          'Error al cargar técnicos: ${estadoAsync.error}',
          style: TipografiaApp.cuerpo,
        ),
      );
    }

    final tecnicos = ref.watch(tecnicosFiltradosProvider);
    if (tecnicos.isEmpty) {
      return _Vacio(
        hayFiltro: ref.watch(
          tecnicosProvider.select((s) => s.value?.hayFiltro ?? false),
        ),
      );
    }

    final especializaciones =
        ref.watch(especializacionesProvider).value ?? const <Especializacion>[];
    final nombreEspecializacion = {
      for (final e in especializaciones) e.id: e.nombre,
    };
    final ordenes = ref.watch(conteoOrdenesPorTecnicoProvider).value ?? const {};

    final pagina = ref.watch(
      tecnicosProvider.select((s) => (
            actual: s.value?.pagina ?? 0,
            total: s.value?.total ?? 0,
            paginas: s.value?.totalPaginas ?? 1,
            tamano: s.value?.tamanoPagina ?? 20,
          )),
    );

    return Column(
      children: [
        Expanded(child: _grilla(tecnicos, nombreEspecializacion, ordenes)),
        if (pagina.paginas > 1)
          PaginacionWidget(
            paginaActual: pagina.actual,
            totalPaginas: pagina.paginas,
            totalItems: pagina.total,
            itemsPorPagina: pagina.tamano,
            alCambiarPagina: (p) =>
                ref.read(tecnicosProvider.notifier).irAPagina(p),
          ),
      ],
    );
  }

  /// El mockup usa `minmax(300px, 1fr)`. El alto reserva sitio para el
  /// nombre en dos líneas y la franja de especialización del pie.
  Widget _grilla(
    List<Tecnico> tecnicos,
    Map<int, String> nombreEspecializacion,
    Map<int, int> ordenes,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisExtent: 156,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: tecnicos.length,
      itemBuilder: (context, i) {
        final tecnico = tecnicos[i];

        return TarjetaTecnico(
          key: ValueKey(tecnico.id),
          tecnico: tecnico,
          especializacion: nombreEspecializacion[tecnico.especializacionId],
          ordenes: ordenes[tecnico.id] ?? 0,
          alPresionar: () => widget.alEditar(tecnico),
          alEditar: () => widget.alEditar(tecnico),
          alEliminar: () => _eliminar(tecnico),
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
            Icons.engineering_outlined,
            size: 44,
            color: ColoresApp.textDisabled,
          ),
          const SizedBox(height: 14),
          Text(
            hayFiltro
                ? 'Ningún técnico coincide con el filtro'
                : 'Aún no hay técnicos',
            style: TipografiaApp.subtitulo,
          ),
          const SizedBox(height: 6),
          Text(
            hayFiltro
                ? 'Prueba con otro término o quita el filtro de estado.'
                : 'Crea el primero con "Nuevo técnico".',
            style: TipografiaApp.caption,
          ),
        ],
      ),
    );
  }
}
