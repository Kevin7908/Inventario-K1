# encabezados/ — Encabezados de pantalla

`lib/frontend/share2/encabezados/`

Widget para el bloque de título y subtítulo que aparece en la parte superior de cada pantalla del proyecto (ej. "Configuración" / "Ajustes generales del negocio y catálogos base").

---

## Widgets previstos

| Widget | Archivo | Estado |
|---|---|---|
| `EncabezadoPagina` | `encabezado_pagina.dart` | Pendiente |

---

## Ejemplo de uso (previsto)

```dart
EncabezadoPagina(
  titulo: 'Configuración',
  subtitulo: 'Ajustes generales del negocio y catálogos base',
)
```

- `titulo` usa `TipografiaApp.heading1`.
- `subtitulo` usa `TipografiaApp.cuerpo` con `ColoresApp.textSecondary`.

---

## Criterio para agregar un widget nuevo

Un widget de esta carpeta define únicamente el título y subtítulo de una pantalla. **No** decide el layout del resto de la página ni el contenido que va debajo de él — eso lo arma cada feature. Si una pantalla necesita acciones junto al encabezado (ej. un botón a la derecha del título), esto se resuelve con un parámetro opcional (`acciones` o `child`), no con un widget nuevo.
