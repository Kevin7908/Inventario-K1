import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/categorias/modelo/categoria.dart';
import '../../../../share2/share2.dart';
import '../../../categorias/provider/categorias_provider.dart';
import '../provider/orden_editor_provider.dart';

/// Adaptador entre `catalogoCategoriasProvider` y [PanelCategorias], para el
/// editor de órdenes.
///
/// Es el mismo panel colapsable de Productos y del editor de cotizaciones —se
/// contrae a una tira de íconos para devolverle ancho a la rejilla— con la
/// diferencia de que aquí la categoría activa vive en el estado del editor.
///
/// El estado del panel (abierto/cerrado y su búsqueda) vive aquí y no en el
/// editor: es interfaz local, y tenerlo arriba haría que teclear una categoría
/// reconstruyera también la rejilla y el panel de la orden.
class PanelCategoriasOrden extends ConsumerStatefulWidget {
  const PanelCategoriasOrden({
    super.key,
    required this.ordenId,
    this.habilitado = true,
  });

  final int ordenId;

  /// En `false` el panel se ve pero no filtra: es lo que pasa con los
  /// servicios y el cargo suelto, que no están categorizados.
  final bool habilitado;

  @override
  ConsumerState<PanelCategoriasOrden> createState() =>
      _PanelCategoriasOrdenState();
}

class _PanelCategoriasOrdenState extends ConsumerState<PanelCategoriasOrden> {
  final _controladorBusqueda = TextEditingController();
  String _busqueda = '';
  bool _expandido = true;

  @override
  void dispose() {
    _controladorBusqueda.dispose();
    super.dispose();
  }

  /// Al contraerlo se limpia su búsqueda: en la tira de íconos no se ve el
  /// buscador, y dejar una lista recortada sin explicar por qué confunde.
  void _alternar() => setState(() {
        _expandido = !_expandido;
        if (!_expandido) {
          _busqueda = '';
          _controladorBusqueda.clear();
        }
      });

  @override
  Widget build(BuildContext context) {
    final provider = ordenEditorProvider(widget.ordenId);
    final seleccionada = ref.watch(provider.select((s) => s.value?.categoriaId));
    final categorias =
        ref.watch(catalogoCategoriasProvider).value ?? const <Categoria>[];

    final query = _busqueda.trim().toLowerCase();
    final items = [
      for (final categoria in categorias)
        if (categoria.id != null &&
            (query.isEmpty || categoria.nombre.toLowerCase().contains(query)))
          CategoriaPanelDato(
            id: categoria.id!,
            nombre: categoria.nombre,
            color: colorDeHex(categoria.colorHex),
          ),
    ];

    return PanelCategorias(
      categorias: items,
      seleccionada: seleccionada,
      alSeleccionar: (id) => ref.read(provider.notifier).filtrarPorCategoria(id),
      expandido: _expandido,
      alAlternar: _alternar,
      controladorBusqueda: _controladorBusqueda,
      alBuscar: (texto) => setState(() => _busqueda = texto),
      habilitado: widget.habilitado,
    );
  }
}
