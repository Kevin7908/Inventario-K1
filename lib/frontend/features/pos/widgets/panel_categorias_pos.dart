import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/categorias/modelo/categoria.dart';
import '../../../share2/share2.dart';
import '../../categorias/provider/categorias_provider.dart';
import '../provider/pos_providers.dart';

/// Adaptador entre `catalogoCategoriasProvider` y [PanelCategorias], para el
/// punto de venta.
///
/// Es el mismo panel colapsable de Productos y del editor de cotizaciones. En
/// el diseño las categorías son chips en fila sobre la rejilla; aquí van al
/// costado porque el taller tiene más categorías de las que caben en una fila
/// —se comerían dos renglones de pantalla— y porque contraído deja la rejilla
/// casi tan ancha como sin panel.
///
/// El estado del panel (abierto/cerrado y su búsqueda) vive aquí y no en el
/// carrito: es interfaz local, y tenerlo arriba haría que teclear una
/// categoría reconstruyera también la rejilla y el panel de la venta.
class PanelCategoriasPos extends ConsumerStatefulWidget {
  const PanelCategoriasPos({super.key});

  @override
  ConsumerState<PanelCategoriasPos> createState() => _PanelCategoriasPosState();
}

class _PanelCategoriasPosState extends ConsumerState<PanelCategoriasPos> {
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
    final seleccionada = ref.watch(posProvider.select((s) => s.categoriaId));
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
      alSeleccionar: ref.read(posProvider.notifier).filtrarPorCategoria,
      expandido: _expandido,
      alAlternar: _alternar,
      controladorBusqueda: _controladorBusqueda,
      alBuscar: (texto) => setState(() => _busqueda = texto),
    );
  }
}
