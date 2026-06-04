import '../../features/productos/modelo/producto.dart';

/// Normaliza un nombre de categoría: elimina tildes, espacios y caracteres
/// especiales, y convierte a mayúsculas. Resultado listo para derivar el
/// prefijo del SKU.
String normalizarCategoria(String nombre) {
  const mapa = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
    'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U', 'Ñ': 'N',
  };
  return nombre
      .split('')
      .map((c) => mapa[c] ?? c)
      .join()
      .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
      .toUpperCase();
}

/// Calcula el prefijo más corto (mínimo 3 letras) para [nombreCategoria] que
/// no colisione con ningún producto de [otrosProductos].
/// Si hay conflicto en 3 letras, agrega una letra más hasta resolver.
String prefijoPara(String nombreCategoria, List<Producto> otrosProductos) {
  final base = normalizarCategoria(nombreCategoria);
  if (base.isEmpty) return 'PRD';

  var prefijo = base.substring(0, base.length.clamp(0, 3));
  for (var len = 3; len <= base.length; len++) {
    final candidato = base.substring(0, len);
    final conflicto = otrosProductos.any((p) =>
        RegExp('^${RegExp.escape(candidato)}-(\\d+)\$')
            .hasMatch(p.sku.toUpperCase()));
    prefijo = candidato;
    if (!conflicto) break;
  }
  return prefijo;
}
