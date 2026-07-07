# Temas — Tokens globales de diseño

Carpeta: `lib/frontend/share2/temas/`

Cualquier valor de color, tamaño de texto o peso de fuente que se use en la UI **debe venir de aquí**. Cambiar un token aquí lo propaga a toda la app.

---

## `colores_app.dart` — `ColoresApp`

La paleta tiene una jerarquía deliberada: **pocos colores saturados** (los verdes de marca) sobre una base de **grises neutros o verdosos**. El error más común que hace que la UI se vea "arcoíris" en vez de premium es mezclar grises neutros (`Colors.grey`) con los grises verdosos del sidebar, o usar un color sólido donde el diseño pide una versión translúcida. Ver la sección "Reglas del sidebar" más abajo.

### Verdes — marca y acciones principales

| Constante | Hex | Cuándo usarlo |
|---|---|---|
| `goGreen` | `#01B763` | Botón primario, foco de input, precios, badge de éxito/stock OK |
| `castletonGreen` | `#005B31` | Hover de botones y elementos primarios |
| `brightGreen` | `#2BD17E` | Texto/ícono **activo** sobre el sidebar oscuro (nunca sobre fondo claro) |
| `greenChipBg` | `#E4F7EE` | Fondo de chips de estado positivo. Solo detrás de texto pequeño, nunca como fondo grande |

### Oscuros — estructura, no acción

| Constante | Hex | Cuándo usarlo |
|---|---|---|
| `blackChocolate` | `#16201B` | Fondo del sidebar y botones secundarios "fuertes" (ej. "Reabastecer inventario"). Es el color de autoridad/estructura, no de acción |
| `textPrimary` | `#19211D` | Texto principal sobre fondo claro (más cálido que negro puro) |

### Grises verdosos — SOLO dentro del sidebar oscuro

Estos tres tonos existen exclusivamente para texto sobre `bgSidebar`. Nunca se usan sobre fondo claro (para eso están `textSecondary`/`textMuted`/`textDisabled` más abajo).

| Constante | Hex | Cuándo usarlo |
|---|---|---|
| `textSidebar` | `#93A29A` | Texto/ícono de un ítem de navegación **inactivo** — el más legible de los tres |
| `textSidebarSecondary` | `#6E7F75` | Subtítulo del sidebar (ej. "Taller de motos") |
| `textSidebarLabel` | `#566256` | Etiquetas de sección (PRINCIPAL, INVENTARIO, TALLER…) — el más apagado, menor énfasis |

### Grises neutros — fondo y jerarquía en contenido claro

| Constante | Hex | Cuándo usarlo |
|---|---|---|
| `bgApp` | `#F4F5F6` | Fondo general de la aplicación |
| `bgCard` | `#FFFFFF` | Tarjetas, paneles, topbar |
| `bgCardHover` | `#FAFBFA` | Hover sutil sobre tarjeta o fila |
| `bgInput` | `#FAFBFA` | Fondo de inputs y del encabezado de `TablaGenerica` — los distingue del blanco de las tarjetas |
| `bgSidebar` | `#16201B` | Fondo de la barra lateral |
| `border` | `#EAECEA` | Borde por defecto de cards, inputs y filas |
| `borderFocus` | `#01B763` | Borde de input cuando tiene foco |
| `borderSidebar` | `#243128` | Separadores dentro del sidebar |

### Texto sobre fondo claro

Tres tonos de gris verdoso con distinto nivel de énfasis — de más a menos legible:

| Constante | Hex | Cuándo usarlo |
|---|---|---|
| `textSecondary` | `#5B6B61` | Labels, subtítulos — el de mayor contraste de los tres |
| `textMuted` | `#8A988F` | Metadatos (fechas, SKU) — un escalón más suave que `textSecondary` |
| `textDisabled` | `#9AA8A0` | Placeholders, campos deshabilitados — el más tenue |
| `textPrimary` | `#19211D` | Títulos, cuerpo principal |
| `textOnPrimary` | `#FFFFFF` | Texto encima de botón/fondo verde |
| `textLink` | `#01B763` | Links y acciones secundarias en texto |

### Estados / badges (semáforo — uso puntual, no decorativo)

| Constante | Hex | Bg | Cuándo usarlo |
|---|---|---|---|
| `statusSuccess` | `#01B763` | `statusSuccessBg` (`#E4F7EE`) | Pagado, activo, stock OK |
| `statusWarning` | `#E0892A` | `statusWarningBg` (`#FFF4E5`) | Pendiente, stock bajo, en proceso |
| `statusDanger` | `#E74C3C` | `statusDangerBg` (`#FDECEA`) | Error, deuda, eliminación, stock agotado |
| `statusInfo` | `#3B82F6` | `statusInfoBg` (`#EEF1FB`) | Información neutral (no es ni bueno ni malo): proveedores, cotización enviada |
| `statusNeutral` | `#5B6B61` | `statusNeutralBg` (`#F0F2F0`) | Cancelado, inactivo, sin estado relevante |

### Stock

| Constante | Cuándo usarlo |
|---|---|
| `stockOk` | Cantidad de stock suficiente |
| `stockLow` | Stock bajo, cerca del mínimo |
| `stockOut` | Stock agotado |

### Sombras

| Constante | Cuándo usarlo |
|---|---|
| `shadow` | Sombra suave de cards |
| `shadowMedium` | Sombra de diálogos y paneles flotantes |

---

## Reglas del sidebar (por qué se ve "premium" y no "arcoíris")

El sidebar usa deliberadamente **dos colores + un acento**, nunca gradientes ni grises neutros sueltos:

1. **Fondo sólido `blackChocolate` (`#16201B`)** — es casi negro, no un gris medio. Un gris medio se ve plano/apagado.
2. **Texto/íconos inactivos en los tres grises verdosos de arriba** (`textSidebar` / `textSidebarSecondary` / `textSidebarLabel`) — nunca `Colors.grey` ni blanco puro. Un gris neutro choca visualmente con el verde de marca y produce el efecto "arcoíris".
3. **Ítem activo: texto/ícono en `brightGreen` (`#2BD17E`) + fondo en `goGreen` al 15% de opacidad** (`ColoresApp.goGreen.withValues(alpha: 0.15)`), **no** un verde sólido. Es el mismo verde de marca pero translúcido, para que se funda con el fondo oscuro en vez de verse como un bloque de color plano. Este es el detalle que más cambia la percepción de calidad — un fondo sólido se ve genérico, uno translúcido se ve diseñado.
4. **El único blanco puro (`#FFFFFF`) de todo el sidebar es la placa del logo** (el rounded rect blanco dentro de `assets/images/logo-k1.svg`). Nada más en el sidebar debería ser blanco puro.

Si un widget nuevo vive dentro del sidebar y necesita un color de texto, la pregunta correcta es "¿qué tan legible debe ser respecto a los otros elementos ya presentes?", no "¿qué gris se ve bien a ojo?" — usar siempre uno de los tres tokens `textSidebar*` de arriba.

---

## `tipografia_app.dart` — `TipografiaApp`

Fuente: **General Sans** (Regular 400 · Medium 500 · SemiBold 600 · Bold 700).

> **Pendiente conocido:** `pubspec.yaml` no tiene declarada ninguna fuente (no existe sección `flutter > fonts`) y no hay archivos `.ttf`/`.otf` de General Sans en el repo. Mientras no se agreguen esos archivos, todo el texto de la app cae al font fallback del sistema — el `fontFamily: 'GeneralSans'` de este archivo no tiene efecto. Los pesos (`FontWeight`) sí se respetan con el fallback, pero la tipografía real de marca solo se verá al agregar los archivos de fuente reales a `assets/fonts/` y registrarlos en `pubspec.yaml`.

### Estilos base

| Estilo | Peso | Tamaño | Cuándo usarlo |
|---|---|---|---|
| `heading1` | Bold (700) | 28 | Título principal de pantalla |
| `heading2` | SemiBold (600) | 22 | Título de sección o card grande |
| `heading3` | SemiBold (600) | 18 | Título de diálogo o panel |
| `subtitulo` | SemiBold (600) | 15 | Nombre de campo, fila destacada |
| `cuerpo` | Medium (500) | 14 | Texto general de la UI |
| `cuerpoMedium` | SemiBold (600) | 14 | Cuerpo con énfasis |
| `caption` | Medium (500) | 12 | Labels de campos, notas |
| `overline` | SemiBold (600) | 11 | Badges, chips, etiquetas cortas |

### Variantes de color (métodos)

Reciben cualquier estilo base y devuelven una copia con el color cambiado.

| Método | Resultado |
|---|---|
| `TipografiaApp.sobrePrimario(estilo)` | Aplica `textOnPrimary` (blanco) |
| `TipografiaApp.deshabilitado(estilo)` | Aplica `textDisabled` |
| `TipografiaApp.enlace(estilo)` | Aplica `textLink` (goGreen) |

### Ejemplo de uso

```dart
Text('Total', style: TipografiaApp.subtitulo),
Text('\$120.000', style: TipografiaApp.heading2),
Text('Campo requerido', style: TipografiaApp.caption),
Text('Guardar', style: TipografiaApp.sobrePrimario(TipografiaApp.cuerpoMedium)),
```
