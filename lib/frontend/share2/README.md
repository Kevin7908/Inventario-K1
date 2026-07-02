# share2 — Biblioteca de Widgets Compartidos

`lib/frontend/share2/`

Este directorio es la **fuente única de verdad** para todos los widgets reutilizables de la aplicación. Cualquier pieza visual que se use en más de una pantalla vive aquí.

---

## Filosofía

El objetivo es **máxima granularidad, mínima repetición**. Cada widget resuelve una sola responsabilidad visual. Los módulos del proyecto (ventas, deudores, inventario) ensamblan estos bloques para construir sus vistas sin duplicar código.

Tres preguntas para saber si algo pertenece a `share2`:

1. ¿Se va a usar en más de una pantalla o módulo?
2. ¿No contiene lógica de negocio propia?
3. ¿Es 100% Flutter nativo (sin dependencias de `pub.dev`)?

Si las tres respuestas son **sí**, va en `share2`.

---

## Regla fundamental

**Todo widget en `share2` es `StatelessWidget`.**

Los widgets aquí son puramente presentacionales. Reciben datos y emiten eventos a través de callbacks. El estado vive siempre en el controlador del módulo que los usa, nunca dentro del widget compartido.

```
❌ share2 decide qué mostrar
✓  share2 recibe qué mostrar y lo pinta
```

---

## Estructura de carpetas

```
share2/
├── README.md                       ← este archivo
├── share2.dart                     ← barrel raíz: importa todo share2 desde aquí
│
├── temas/                          ← tokens de diseño (colores, tipografía)
│   ├── colores_app.dart
│   ├── tipografia_app.dart
│   └── README.md
│
├── botones/                        ← acciones del usuario
│   ├── boton_primario.dart
│   ├── boton_secundario.dart
│   ├── boton_destructivo.dart
│   ├── boton_icono.dart
│   ├── boton_con_carga.dart
│   └── botones.dart                ← barrel de categoría
│
├── inputs/                         ← captura de datos
│   ├── campo_texto.dart
│   ├── campo_moneda.dart
│   ├── selector_widget.dart
│   ├── checkbox_app.dart
│   └── inputs.dart
│
├── tablas/                         ← visualización de colecciones
│   ├── tabla_generica.dart
│   ├── columna_tabla.dart
│   ├── fila_tabla.dart
│   ├── paginacion_widget.dart
│   ├── estado_vacio_widget.dart
│   └── tablas.dart
│
├── cards/                          ← contenedores de información
│   ├── tarjeta_info.dart
│   ├── panel_seccion.dart
│   ├── contenedor_modal.dart
│   └── cards.dart
│
├── feedback/                       ← respuesta visual al usuario
│   ├── badge_contador.dart
│   ├── snackbar_app.dart
│   ├── loader_pantalla.dart
│   ├── dialogo_confirmacion.dart
│   ├── indicador_estado.dart
│   └── feedback.dart
│
└── nav/                            ← navegación principal
    ├── logo_sidebar.dart
    ├── seccion_nav.dart
    ├── item_nav.dart
    ├── separador_nav.dart
    ├── barra_lateral.dart
    ├── item_nav_dato.dart
    ├── seccion_nav_dato.dart
    ├── README.md
    └── nav.dart
```

---

## Categorías

### `botones/` — Acciones del usuario

Widgets para todas las acciones que puede ejecutar el usuario. Se diferencian por jerarquía visual y tipo de consecuencia.

| Widget | Cuándo usarlo |
|---|---|
| `BotonPrimario` | Acción principal de la pantalla (Guardar, Registrar) |
| `BotonSecundario` | Acción alternativa (Cancelar, Volver) |
| `BotonDestructivo` | Acciones irreversibles (Eliminar, Anular) |
| `BotonIcono` | Acciones compactas que se entienden con un ícono |
| `BotonConCarga` | Igual que `BotonPrimario` pero muestra un spinner mientras `enCarga: true` |

---

### `inputs/` — Captura de datos

Widgets para formularios y entrada de datos. Aplican el estilo visual del proyecto de forma consistente.

| Widget | Cuándo usarlo |
|---|---|
| `CampoTexto` | Entrada de texto general (nombre, descripción) |
| `CampoMoneda` | Entrada de valores numéricos con formato de moneda |
| `SelectorWidget` | Dropdown de opciones predefinidas |
| `CheckboxApp` | Selección booleana estilizada |

---

### `tablas/` — Visualización de colecciones

Widgets para mostrar listas y colecciones de datos de forma tabular. `TablaGenerica` es el más importante: recibe una lista de `ColumnaTabla` que define las columnas dinámicamente.

| Widget | Cuándo usarlo |
|---|---|
| `TablaGenerica` | Tabla configurable con columnas dinámicas |
| `ColumnaTabla` | Define el encabezado, ancho y builder de celda de cada columna |
| `FilaTabla` | Fila individual con estilos de hover y selección |
| `PaginacionWidget` | Navegación entre páginas de una tabla |
| `EstadoVacioWidget` | Pantalla cuando no hay datos que mostrar |

---

### `cards/` — Contenedores de información

Widgets para agrupar y presentar información con estilos consistentes.

| Widget | Cuándo usarlo |
|---|---|
| `TarjetaInfo` | Muestra un KPI o dato destacado (ej: total ventas del día) |
| `PanelSeccion` | Agrupa un bloque de contenido con título y borde |
| `ContenedorModal` | Wrapper base para el contenido de diálogos y modales |

---

### `feedback/` — Respuesta visual al usuario

**Share2 centraliza todo el feedback visual de la aplicación.** Esto garantiza que errores, éxitos y estados de carga se vean igual en todos los módulos.

| Widget | Cuándo usarlo |
|---|---|
| `SnackbarApp` | Notificaciones temporales (éxito, error, advertencia) |
| `LoaderPantalla` | Overlay de carga mientras una operación está en curso |
| `DialogoConfirmacion` | Pide confirmación antes de una acción irreversible |
| `BadgeContador` | Círculo con número para conteos (notificaciones, ítems pendientes) |
| `IndicadorEstado` | Badge/chip de color para mostrar un estado (Pagado, Pendiente, Anulado) |

Todos los módulos deben usar estos widgets para feedback en lugar de implementar sus propios snackbars o loaders.

---

### `nav/` — Navegación principal

Widgets para el sidebar de navegación de la aplicación. Ver [`nav/README.md`](nav/README.md) para ejemplos de uso completos.

| Widget | Cuándo usarlo |
|---|---|
| `BarraLateral` | Sidebar completo con logo, secciones e ítems de pie |
| `LogoSidebar` | Encabezado del sidebar con símbolo K1 y nombre de empresa |
| `SeccionNav` | Etiqueta de grupo (PRINCIPAL, INVENTARIO, TALLER…) |
| `ItemNav` | Fila de navegación: ícono + texto + estado activo + badge |
| `SeparadorNav` | Línea divisora entre nav principal e ítems de pie |

---

### `temas/` — Tokens de diseño

Los colores y la tipografía del proyecto. Ver [`temas/README.md`](temas/README.md) para la referencia completa.

Los widgets de `share2` **no** usan `Theme.of(context)` directamente. Usan `ColoresApp` y `TipografiaApp` que son las fuentes de verdad del diseño visual.

---

## Importaciones

Se usa un barrel raíz `share2.dart` en la raíz de esta carpeta. Es el único punto de importación necesario para cualquier módulo del proyecto.

```dart
// Una sola línea da acceso a todo share2
import 'package:inventario_k1/frontend/share2/share2.dart';
```

Cada categoría también tiene su propio barrel si se quiere importar solo una parte:

```dart
import 'package:inventario_k1/frontend/share2/botones/botones.dart';
import 'package:inventario_k1/frontend/share2/tablas/tablas.dart';
```

**No** se importan archivos individuales directamente. Siempre a través del barrel.

---

## Cómo documentar un widget

Cada widget debe tener un docstring con tres secciones: qué hace, qué parámetros recibe y un ejemplo mínimo de uso. Esto permite entender el widget sin abrir su implementación.

```dart
/// Botón de acción principal de la aplicación.
///
/// Parámetros:
/// - [etiqueta]: texto visible del botón.
/// - [alPresionar]: callback ejecutado al hacer tap. Si es `null`, el botón queda deshabilitado.
/// - [ancho]: ancho personalizado. Por defecto ocupa el ancho de su contenedor.
///
/// Ejemplo:
/// ```dart
/// BotonPrimario(
///   etiqueta: 'Guardar venta',
///   alPresionar: () => controlador.guardar(),
/// )
/// ```
class BotonPrimario extends StatelessWidget { ... }
```

---

## Reglas para agregar un widget nuevo

Antes de crear un widget en `share2`, verificar:

1. **¿Ya existe algo similar?** Buscar en las carpetas de categoría antes de crear uno nuevo. Es preferible extender un widget existente con un parámetro opcional.
2. **¿Pertenece a `share2`?** Debe cumplir las tres condiciones de la sección de filosofía: reutilizable, sin lógica de negocio y sin dependencias externas.
3. **Nombrar correctamente.** El nombre debe ser descriptivo y en español, terminando en el sufijo de su tipo: `Widget`, o el nombre del componente (ej: `BotonPrimario`, `CampoMoneda`, `TablaGenerica`). Archivos en `snake_case`.
4. **Ubicar en la categoría correcta.** Si no encaja en ninguna categoría existente, crear una nueva carpeta con su propio barrel.
5. **Agregar al barrel.** El archivo nuevo debe exportarse en el barrel de su categoría (`categoria/categoria.dart`) y este a su vez debe estar en el barrel raíz (`share2.dart`).
6. **Documentar con el template.** Docstring con descripción, parámetros y ejemplo de uso.

---

## Convenciones de nomenclatura

| Elemento | Convención | Ejemplo |
|---|---|---|
| Archivo | `snake_case` | `boton_primario.dart` |
| Clase widget | `PascalCase` descriptivo | `BotonPrimario` |
| Parámetros | `camelCase` en español | `alPresionar`, `etiqueta`, `enCarga` |
| Barrel de categoría | nombre de carpeta + `.dart` | `botones/botones.dart` |
| Callbacks | prefijo `al` + acción | `alPresionar`, `alSeleccionar`, `alCambiar` |

---

## Qué NO va en share2

Para mantener la carpeta limpia y enfocada:

- **Lógica de negocio**: validaciones de negocio, cálculos, llamadas a repositorios.
- **Widgets específicos de un módulo**: si solo se usa en ventas, vive en `features/ventas/`.
- **Layout de pantalla completa**: la estructura de cada pantalla (qué va arriba, qué va al lado) la decide cada feature, no share2.
- **Dependencias de `pub.dev`**: cero paquetes externos. Solo Flutter SDK.

---

## Relación con `share` (legacy)

La carpeta `lib/frontend/share/` está **congelada y no se toca**. No se corrige, no se extiende, no se migra nada de ahí. Existe solo como referencia histórica.

Todo trabajo de widgets, sin excepción, ocurre en `share2`.
