import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/productos/modelo/producto.dart';
import '../../../../features/productos/provider/productos_provider.dart';
import 'pos_notifier.dart';
import 'pos_state.dart';

// ── POS notifier ──────────────────────────────────────────────────────────────

final posProvider = NotifierProvider<PosNotifier, PosState>(
  PosNotifier.new,
  name: 'posProvider',
);

// ── Catálogo filtrado por búsqueda y categoría ────────────────────────────────

final posCatalogoProvider = Provider<List<Producto>>(
  name: 'posCatalogoProvider',
  (ref) {
    final todos  = ref.watch(catalogoCompletoProvider).value ?? const [];
    final pos    = ref.watch(posProvider);
    final q      = pos.buscando.toLowerCase();
    final cat    = pos.categoriaFiltro;

    var lista = todos.where((p) => p.activo).toList(growable: false);

    if (cat != null && cat.isNotEmpty) {
      lista = lista
          .where((p) => p.categoriaNombre == cat)
          .toList(growable: false);
    }

    if (q.isNotEmpty) {
      lista = lista.where((p) {
        return p.nombre.toLowerCase().contains(q) ||
               p.sku.toLowerCase().contains(q);
      }).toList(growable: false);
    }

    return lista;
  },
);

/// Categorías únicas de los productos activos.
final posCategoriasProvider = Provider<List<String>>(
  name: 'posCategoriasProvider',
  (ref) {
    final todos = ref.watch(catalogoCompletoProvider).value ?? const [];
    final cats  = <String>{};
    for (final p in todos) {
      if (p.activo && p.categoriaNombre != null) {
        cats.add(p.categoriaNombre!);
      }
    }
    return cats.toList()..sort();
  },
);
