import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/especializacion/modelo/especializacion.dart';
import '../../../share/share.dart';
import '../../tecnicos/provider/tecnico_provider.dart';
import '../provider/especializacion_provider.dart';
import '../widgets/dialogo_especializacion.dart';

/// Pestaña "Especializaciones" de Configuración: catálogo de áreas técnicas
/// presentado como grilla de tarjetas, con creación, edición y eliminación.
///
/// Vive fuera de `share` porque conecta con [especializacionesProvider] y
/// [catalogoTecnicosProvider] (Riverpod) — share es puramente presentacional.
class EspecializacionesVista extends ConsumerStatefulWidget {
  const EspecializacionesVista({super.key});

  @override
  ConsumerState<EspecializacionesVista> createState() =>
      _EspecializacionesVistaState();
}

class _EspecializacionesVistaState
    extends ConsumerState<EspecializacionesVista> {
  final _busquedaController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaController.dispose();
    super.dispose();
  }

  void _alBuscar(String texto) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      ref.read(busquedaEspecializacionProvider.notifier).state = texto;
    });
  }

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

  Future<void> _eliminar(Especializacion especializacion) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Eliminar "${especializacion.nombre}"?',
      mensaje: 'Esta acción no se puede deshacer.',
    );
    if (confirmado != true || !mounted) return;

    final error = await ref
        .read(especializacionesProvider.notifier)
        .eliminar(especializacion.id);
    if (!mounted || error == null) return;
    _mostrarError(error);
  }

  /// Cuenta cuántos técnicos tienen asignada cada especialización.
  /// Se deriva en la vista a partir de datos ya cargados: no consulta la BD
  /// ni agrega lógica al backend.
  Map<int, int> _tecnicosPorEspecializacion() {
    final tecnicos = ref.watch(catalogoTecnicosProvider).value ?? const [];
    final conteo = <int, int>{};
    for (final tecnico in tecnicos) {
      final id = tecnico.especializacionId;
      if (id != null) conteo[id] = (conteo[id] ?? 0) + 1;
    }
    return conteo;
  }

  @override
  Widget build(BuildContext context) {
    final asyncFiltradas = ref.watch(especializacionesFiltradasProvider);
    final busqueda = ref.watch(busquedaEspecializacionProvider);

    // Sin `ConstrainedBox`: a diferencia de las tablas, la grilla aprovecha
    // todo el ancho disponible para caber más tarjetas por fila.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: BarraBusqueda(
                controlador: _busquedaController,
                placeholder: 'Buscar especialización...',
                alCambiar: _alBuscar,
              ),
            ),
            const SizedBox(width: 20),
            BotonPrimario(
              etiqueta: 'Agregar especialización',
              icono: Icons.add,
              alPresionar: () => DialogoEspecializacion.mostrar(context),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: asyncFiltradas.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: ColoresApp.goGreen),
            ),
            error: (e, _) => Center(
              child: Text(
                'Error al cargar especializaciones: $e',
                style: TipografiaApp.cuerpo,
              ),
            ),
            data: (lista) => lista.isEmpty ? _vacio(busqueda) : _grilla(lista),
          ),
        ),
      ],
    );
  }

  Widget _grilla(List<Especializacion> lista) {
    final conteo = _tecnicosPorEspecializacion();

    // Sin `Scrollbar` explícito: en escritorio `MaterialScrollBehavior` ya la
    // añade con el controller correcto.
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      // Tarjetas anchas y con alto para dos líneas de título, para que los
      // nombres largos ("Frenos y suspensión") se lean completos.
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 420,
        mainAxisExtent: 104,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: lista.length,
      itemBuilder: (context, i) {
        final especializacion = lista[i];
        final total = conteo[especializacion.id] ?? 0;

        return TarjetaCatalogo(
          icono: Icons.build_outlined,
          titulo: especializacion.nombre,
          subtitulo: total == 1 ? '1 técnico' : '$total técnicos',
          acciones: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BotonIcono(
                icono: Icons.edit_outlined,
                tooltip: 'Editar',
                alPresionar: () => DialogoEspecializacion.mostrar(
                  context,
                  especializacionAEditar: especializacion,
                ),
              ),
              BotonIcono(
                icono: Icons.delete_outline_rounded,
                tooltip: 'Eliminar',
                color: ColoresApp.statusDanger,
                alPresionar: () => _eliminar(especializacion),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _vacio(String busqueda) {
    final hayFiltro = busqueda.trim().isNotEmpty;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.build_circle_outlined,
            size: 44,
            color: ColoresApp.textDisabled,
          ),
          const SizedBox(height: 14),
          Text(
            hayFiltro
                ? 'Sin resultados para "$busqueda"'
                : 'Aún no hay especializaciones',
            style: TipografiaApp.subtitulo,
          ),
          const SizedBox(height: 6),
          Text(
            hayFiltro
                ? 'Prueba con otro término de búsqueda.'
                : 'Crea la primera con "Agregar especialización".',
            style: TipografiaApp.caption,
          ),
        ],
      ),
    );
  }
}
