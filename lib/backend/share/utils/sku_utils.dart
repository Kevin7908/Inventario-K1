/// El prefijo del SKU sale del nombre de la categoría.
///
/// `Aceites` → `ACE-001`, `Frenos` → `FRE-001`, sin categoría → `PRD-001`.
///
/// **Se deriva, no se guarda.** Una columna `prefijo` en `categorias` sería un
/// campo más que llenar y que validar por algo que el nombre ya dice. El
/// precio de derivarlo es que renombrar una categoría no reescribe los SKU
/// viejos —y eso es lo correcto: un SKU está impreso en la etiqueta de la
/// estantería, y un código que cambia solo deja de servir para lo único que
/// sirve—.
library;

import 'texto_utils.dart';

/// Cuántas letras tiene un prefijo antes de alargarse para desempatar.
const int _largoBase = 3;

/// El prefijo de lo que no tiene categoría.
const String prefijoSinCategoria = 'PRD';

/// Quita tildes y todo lo que no sea letra o dígito, y pasa a mayúsculas.
///
/// El mapa de tildes es el mismo que usa el buscador del catálogo, y por eso
/// vive en `texto_utils.dart`: tenerlo dos veces era la forma de que un día
/// dejaran de coincidir.
String normalizarCategoria(String nombre) => aplanarTexto(nombre)
    .replaceAll(RegExp(r'[^a-z0-9]'), '')
    .toUpperCase();

/// El prefijo de [nombre], alargado lo justo para no chocar con [anteriores].
///
/// [anteriores] son los nombres de las categorías **creadas antes** que esta,
/// en orden. Que el desempate mire hacia atrás y no hacia adelante es lo que
/// hace el resultado estable: la categoría que llegó primero se queda con el
/// prefijo corto y crear una nueva no le cambia el suyo a nadie.
///
/// Ejemplo:
/// ```dart
/// prefijoDeCategoria('Aceites', const []);            // ACE
/// prefijoDeCategoria('Accesorios', const ['Aceites']); // ACCE
/// ```
String prefijoDeCategoria(String nombre, List<String> anteriores) {
  final base = normalizarCategoria(nombre);
  if (base.isEmpty) return prefijoSinCategoria;

  final usados = <String>{};
  for (final previo in anteriores) {
    final suyo = normalizarCategoria(previo);
    if (suyo.isEmpty) continue;
    usados.add(_recorte(suyo, _largoBase));
  }

  for (var largo = _largoBase; largo <= base.length; largo++) {
    final candidato = _recorte(base, largo);
    // Solo el primer tramo entra en conflicto: dos categorías distintas con
    // las mismas tres letras iniciales se separan alargando esta.
    if (largo > _largoBase || !usados.contains(candidato)) return candidato;
  }

  // El nombre entero choca con otro ya normalizado —«Frenos» y «¡Frenos!»—.
  // El repositorio rechaza el nombre duplicado antes de llegar aquí, así que
  // esto es la red por si algún día deja de hacerlo.
  return base;
}

/// [texto] recortado a [largo], sin pasarse de su propio tamaño.
String _recorte(String texto, int largo) =>
    texto.substring(0, largo.clamp(0, texto.length));

/// El SKU completo: `ACE` + 4 → `ACE-004`.
String formatearSku(String prefijo, int numero) =>
    '$prefijo-${numero.toString().padLeft(3, '0')}';
