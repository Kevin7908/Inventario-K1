# Temas — Tokens globales de diseño

Carpeta: `lib/frontend/share2/temas/`

Cualquier valor de color, tamaño de texto o peso de fuente que se use en la UI **debe venir de aquí**. Cambiar un token aquí lo propaga a toda la app.

---

## `colores_app.dart` — `ColoresApp`

### Paleta de marca

| Constante | Hex | Cuándo usarlo |
|---|---|---|
| `goGreen` | `#01B763` | Botón primario, foco de input, badge de éxito/OK |
| `castletonGreen` | `#005B31` | Sidebar, hover de elementos primarios |
| `blackChocolate` | `#1E4C3C` | Fondos oscuros o de alto contraste |

### Backgrounds

| Constante | Cuándo usarlo |
|---|---|
| `bgApp` | Fondo general de la aplicación |
| `bgCard` | Fondo de tarjetas y paneles |
| `bgCardHover` | Estado hover de una tarjeta |
| `bgSidebar` | Fondo de la barra lateral |
| `bgInput` | Fondo de campos de texto |

### Texto

| Constante | Cuándo usarlo |
|---|---|
| `textPrimary` | Títulos, cuerpo principal |
| `textSecondary` | Labels, descripciones, subtítulos |
| `textDisabled` | Placeholders, campos deshabilitados |
| `textOnPrimary` | Texto encima de botón/fondo verde |
| `textSidebar` | Texto dentro de la barra lateral |
| `textLink` | Links y acciones secundarias en texto |

### Estados / badges

| Constante | Bg | Cuándo usarlo |
|---|---|---|
| `statusSuccess` | `statusSuccessBg` | Pagado, activo, stock OK |
| `statusWarning` | `statusWarningBg` | Pendiente, stock bajo |
| `statusDanger` | `statusDangerBg` | Error, deuda, eliminación, stock agotado |
| `statusInfo` | `statusInfoBg` | Información neutral, en proceso |
| `statusNeutral` | `statusNeutralBg` | Cancelado, inactivo, sin estado relevante |

### Bordes y sombras

| Constante | Cuándo usarlo |
|---|---|
| `border` | Borde por defecto de cards e inputs |
| `borderFocus` | Borde de input cuando tiene foco |
| `borderSidebar` | Separadores dentro del sidebar |
| `shadow` | Sombra suave de cards |
| `shadowMedium` | Sombra de diálogos y paneles flotantes |

---

## `tipografia_app.dart` — `TipografiaApp`

Fuente: **General Sans** (SemiBold · Medium · Regular). Debe estar declarada en `pubspec.yaml` bajo `flutter > fonts` con el nombre de familia `GeneralSans`.

### Estilos base

| Estilo | Peso | Tamaño | Cuándo usarlo |
|---|---|---|---|
| `heading1` | SemiBold | 28 | Título principal de pantalla |
| `heading2` | SemiBold | 22 | Título de sección o card grande |
| `heading3` | SemiBold | 18 | Título de diálogo o panel |
| `subtitulo` | Medium | 15 | Nombre de campo, fila destacada |
| `cuerpo` | Regular | 14 | Texto general de la UI |
| `cuerpoMedium` | Medium | 14 | Cuerpo con énfasis |
| `caption` | Regular | 12 | Labels de campos, notas |
| `overline` | SemiBold | 11 | Badges, chips, etiquetas cortas |

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
