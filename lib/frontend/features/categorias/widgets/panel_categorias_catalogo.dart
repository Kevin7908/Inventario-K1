import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/categorias/modelo/categoria.dart';
import '../../../share2/share2.dart';
import '../provider/categorias_provider.dart';

/// Adaptador entre `catalogoCategoriasProvider` y [PanelCategorias] de share2.
///
/// **Es el único.** Había cuatro copias de este mismo archivo —Productos, el
/// punto de venta, el editor de cotizaciones y el de órdenes—, idénticas salvo
/// de qué provider salía la categoría activa. Cuatro widgets con nombres
/// distintos y la misma tarea es justo lo que prohíbe la regla 0 de
/// `CLAUDE.md`: lo que cambiaba entre ellos son dos parámetros, no un widget.
///
/// Vive en el módulo de Categorías y no en share2 porque **consulta un
/// provider**: share2 recibe datos ya resueltos y no observa nada (regla 0.3).
/// Quien lo usa le pasa qué categoría está activa y qué hacer al elegir otra.
///
/// El estado del panel —abierto/cerrado y la búsqueda de categorías— vive
/// aquí, no arriba: es interfaz local, y tenerlo en el notifier haría que
/// teclear una categoría reconstruyera también la rejilla de productos.
///
/// Parámetros:
/// - [seleccionada]: id de la categoría activa; `null` es «Todas».
/// - [alSeleccionar]: se llama con el id elegido, o `null` para quitar el
///   filtro.
/// - [habilitado]: en `false` el panel se ve pero no filtra (el editor de
///   órdenes lo apaga cuando muestra servicios, que no están categorizados).
///
/// Ejemplo:
/// ```dart
/// PanelCategoriasCatalogo(
///   seleccionada: ref.watch(posProvider.select((s) => s.categoriaId)),
///   alSeleccionar: ref.read(posProvider.notifier).filtrarPorCategoria,
/// )
/// ```
class PanelCategoriasCatalogo extends ConsumerStatefulWidget {
  const PanelCategoriasCatalogo({
    super.key,
    required this.seleccionada,
    required this.alSeleccionar,
    this.habilitado = true,
  });

  final int? seleccionada;
  final ValueChanged<int?> alSeleccionar;
  final bool habilitado;

  @override
  ConsumerState<PanelCategoriasCatalogo> createState() =>
      _PanelCategoriasCatalogoState();
}

class _PanelCategoriasCatalogoState
    extends ConsumerState<PanelCategoriasCatalogo> {
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
      seleccionada: widget.seleccionada,
      alSeleccionar: widget.alSeleccionar,
      expandido: _expandido,
      alAlternar: _alternar,
      controladorBusqueda: _controladorBusqueda,
      alBuscar: (texto) => setState(() => _busqueda = texto),
      habilitado: widget.habilitado,
    );
  }
}
