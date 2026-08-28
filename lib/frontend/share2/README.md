# share2 — Biblioteca de Widgets Compartidos

`lib/frontend/share2/`

Este directorio es la **fuente única de verdad** para todos los widgets reutilizables de la aplicación. Cualquier pieza visual que se use en más de una pantalla vive aquí.

---

## Filosofía

El objetivo es **máxima granularidad, mínima repetición**. Cada widget resuelve una sola responsabilidad visual. Los módulos del proyecto (punto de venta, órdenes, inventario) ensamblan estos bloques para construir sus vistas sin duplicar código.

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
│   ├── hex_color.dart              ← colorDeHex / inicialDe
│   └── README.md
│
├── encabezados/                    ← título y subtítulo de cada pantalla
│   ├── encabezado_pagina.dart
│   ├── README.md
│   └── encabezados.dart
│
├── navegacion_secundaria/          ← pestañas dentro de una pantalla
│   ├── barra_tabs_secundaria.dart
│   ├── tab_secundaria_dato.dart
│   ├── README.md
│   └── navegacion_secundaria.dart
│
├── botones/                        ← acciones del usuario
│   ├── boton_primario.dart
│   ├── boton_secundario.dart
│   ├── boton_destructivo.dart
│   ├── boton_icono.dart
│   ├── boton_volver.dart
│   └── botones.dart                ← barrel de categoría
│
├── inputs/                         ← captura de datos
│   ├── campo_texto.dart
│   ├── selector_widget.dart
│   ├── cuadro_seleccion.dart
│   ├── grupo_radio.dart
│   ├── fila_campos.dart
│   ├── formulario_abono.dart
│   ├── interruptor_campo.dart
│   ├── atajos_formulario.dart
│   ├── barra_busqueda.dart
│   ├── campo_busqueda.dart
│   ├── campo_fecha.dart
│   ├── campo_precio_linea.dart
│   ├── control_cantidad.dart
│   └── inputs.dart
│
├── filtros/                        ← acotar una colección
│   │  (el panel de categorías **con datos** es
│   │   `features/categorias/widgets/panel_categorias_catalogo.dart`)
│   ├── panel_categorias.dart
│   ├── categoria_panel_dato.dart
│   ├── chip_filtro.dart
│   └── filtros.dart
│
├── tablas/                         ← visualización de colecciones
│   ├── tabla_generica.dart
│   ├── columna_tabla.dart
│   ├── fila_tabla.dart
│   ├── paginacion_widget.dart
│   └── tablas.dart
│
├── cards/                          ← contenedores de información
│   ├── fila_documento.dart
│   ├── panel_documento.dart
│   ├── encabezado_grupo_lineas.dart
│   ├── tarjeta_info.dart
│   ├── tarjeta_metrica.dart
│   ├── tarjeta_catalogo.dart
│   ├── tarjeta_producto.dart
│   ├── ficha_resumen.dart
│   ├── pie_totales.dart
│   ├── renglon_cuenta.dart
│   ├── fila_movimiento.dart
│   ├── marcador_identidad.dart
│   ├── fila_dato.dart
│   ├── panel_seccion.dart
│   └── cards.dart
│
├── feedback/                       ← respuesta visual al usuario
│   ├── aviso_en_linea.dart
│   ├── badge_contador.dart
│   ├── barra_progreso.dart
│   ├── mensaje_app.dart
│   ├── dialogo_confirmacion.dart
│   ├── estado_vacio.dart
│   ├── icono_notificaciones.dart
│   ├── indicador_estado.dart
│   └── feedback.dart
│
├── nav/                            ← navegación principal
│   ├── logo_sidebar.dart
│   ├── seccion_nav.dart
│   ├── item_nav.dart
│   ├── separador_nav.dart
│   ├── barra_lateral.dart
│   ├── item_nav_dato.dart
│   ├── seccion_nav_dato.dart
│   ├── README.md
│   └── nav.dart
│
└── cuenta/                         ← sesión del usuario logueado
    ├── avatar_usuario.dart
    ├── cuenta_usuario_widget.dart
    ├── README.md
    └── cuenta.dart
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
| `BotonVolver` | Flecha de regreso de las pantallas de detalle |

---

### `inputs/` — Captura de datos

Widgets para formularios y entrada de datos. Aplican el estilo visual del proyecto de forma consistente.

| Widget | Cuándo usarlo |
|---|---|
| `CampoTexto` | Entrada de texto general (nombre, descripción). Con `oculto` sirve de contraseña, y con `alAlternarOculto` aparece el ojo — el estado del ojo lo lleva la vista, no el widget |
| `SelectorWidget` | Dropdown de opciones predefinidas |
| `CuadroSeleccion` | Selección booleana estilizada |
| `GrupoRadio` | Elegir una opción de pocas, en fila |
| `BarraBusqueda` | Campo de búsqueda con ícono, para filtrar listas o tablas |
| `CampoBusqueda` | Selector con buscador, para listas largas (clientes, motos) |
| `CampoFecha` | Fecha con etiqueta que abre el calendario del sistema |
| `CampoPrecioLinea` | El precio tecleable de una línea, sin cajón, alineado con el precio fijo |
| `ControlCantidad` | Cantidad de una línea: `–`, `+` y el número editable a mano |
| `FilaCampos` | Reparte campos en una fila y los apila cuando falta ancho |
| `InterruptorCampo` | Switch con etiqueta y una línea que explica qué implica el estado |
| `FormularioAbono<T>` | Recibir plata contra un documento: monto acotado al saldo, método de pago y «Todo el saldo». Lo comparten el abono de una reserva y el pago de una deuda |
| `AtajosFormulario` | Esc cancela, Ctrl/Cmd+Enter guarda |

---

### `tablas/` — Visualización de colecciones

Widgets para mostrar listas y colecciones de datos de forma tabular. `TablaGenerica` es el más importante: recibe una lista de `ColumnaTabla` que define las columnas dinámicamente.

| Widget | Cuándo usarlo |
|---|---|
| `TablaGenerica` | Tabla configurable con columnas dinámicas |
| `ColumnaTabla` | Define el encabezado, ancho y builder de celda de cada columna |
| `FilaTabla` | Fila individual con estilos de hover y selección |
| `PaginacionWidget` | Navegación entre páginas de una tabla |

---

### `cards/` — Contenedores de información

Widgets para agrupar y presentar información con estilos consistentes.

| Widget | Cuándo usarlo |
|---|---|
| `TarjetaInfo` | Muestra un KPI o dato destacado (ej: total ventas del día) |
| `TarjetaCatalogo` | Ítem de catálogo en grilla o fila: marcador, título, subtítulo, acciones y `pie` opcional |
| `TarjetaProducto` | Tarjeta de las rejillas de venta: foto, SKU, stock, ubicación en bodega, precio y botón de agregar |
| `TarjetaMetrica` | Contador grande que además filtra al tocarlo |
| `FilaDocumento` | Una línea del documento que se arma: cuadro de 48, título, precio y controles. La usan el carrito, la cotización y la orden |
| `PanelDocumento` | El aside de 360 px con cabecera, contenido y pie |
| `EncabezadoGrupoLineas` | Separador de un bloque de líneas con su subtotal |
| `FichaResumen` | Bloque de datos de una entidad, para cabeceras de detalle |
| `PieTotales` | Pie de un documento: subtotal, descuento editable, total e IVA incluido |
| `RenglonCuenta` | Un renglón «etiqueta … importe» del bloque de cuentas. El color lo decide quien lo usa: un saldo pendiente no significa lo mismo en una reserva que en una deuda |
| `FilaMovimiento` | Una línea del historial de dinero: ícono, qué fue, cuándo y cuánto. La comparten los abonos de una reserva y los pagos de una deuda |
| `MarcadorIdentidad` | Cuadro con el ícono de la entidad o la inicial de su nombre sobre su color |
| `FilaDato` | Línea "ícono + texto" dentro de una tarjeta (contacto, teléfono, ciudad) |
| `PanelSeccion` | Agrupa un bloque de contenido con título y borde |

---

### `feedback/` — Respuesta visual al usuario

**Share2 centraliza todo el feedback visual de la aplicación.** Esto garantiza que errores, éxitos y estados de carga se vean igual en todos los módulos.

| Widget | Cuándo usarlo |
|---|---|
| `MensajeApp` | El aviso breve de abajo: `MensajeApp.exito(context, …)` / `.error(…)`. No es un widget sino dos funciones, como `colorDeHex` |
| `AvisoEnLinea` | El aviso que **se queda** dentro del contenido, con su tono (`información`, `éxito`, `alerta`, `error`). Para lo que el usuario todavía tiene que leer mientras decide: «la contraseña no coincide», «el correo no está configurado». `MensajeApp` confirma lo que ya pasó; este acompaña |
| `DialogoConfirmacion` | Pide confirmación antes de una acción irreversible |
| `BadgeContador` | Círculo con número para conteos (notificaciones, ítems pendientes) |
| `IndicadorEstado` | Badge/chip de color para mostrar un estado (Pagado, Pendiente, Anulado) |
| `EstadoVacio` | El hueco de una lista sin nada: ícono, qué falta y cómo llenarlo |
| `BarraProgreso` | Cuánto se lleva de un total: reservas abonadas, deudas cobradas |

Todos los módulos deben usar estos widgets para feedback en lugar de implementar sus propios snackbars o loaders. Quedan pantallas legacy con su `_avisar` propio: se pasan a `MensajeApp` al tocarlas.

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

### `cuenta/` — Sesión del usuario logueado

Widgets para mostrar quién está usando la aplicación. Ver [`cuenta/README.md`](cuenta/README.md).

| Widget | Cuándo usarlo |
|---|---|
| `CuentaUsuarioWidget` | Avatar + nombre + rol del usuario logueado, típicamente como `acciones` de `EncabezadoPagina` |
| `AvatarUsuario` | Círculo con iniciales, reutilizable fuera de `CuentaUsuarioWidget` |

---

### `encabezados/` — Encabezados de pantalla

Bloque de título y subtítulo que va en la parte superior de cada pantalla. Ver [`encabezados/README.md`](encabezados/README.md).

| Widget | Cuándo usarlo |
|---|---|
| `EncabezadoPagina` | Título + subtítulo de una pantalla (ej. "Configuración" / "Ajustes generales del negocio y catálogos base") |

---

### `navegacion_secundaria/` — Pestañas dentro de una pantalla

Navegación entre secciones de contenido dentro de una misma pantalla (distinta del sidebar). Ver [`navegacion_secundaria/README.md`](navegacion_secundaria/README.md).

| Widget | Cuándo usarlo |
|---|---|
| `BarraTabsSecundaria` | Grupo de pestañas para alternar entre bloques de contenido de una pantalla (ej. General / Unidades de medida / Especializaciones / Servicios) |

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

## Lo que se comparte pero no cabe aquí

Hay piezas que usan tres pantallas y aun así **no** pueden vivir en `share2`,
porque consultan un provider o conocen el modelo de dominio. Esas viven en el
módulo dueño del dato, y el resto las importa:

| Pieza | Vive en | Por qué no es share2 |
|---|---|---|
| `GrillaProductosCatalogo` | `features/productos/widgets/` | Conoce `Producto` y lee la foto del disco |
| `PanelCategoriasCatalogo` | `features/categorias/widgets/` | Observa `catalogoCategoriasProvider` |
| `MiniaturaLinea` | `features/productos/widgets/` | Lee la foto del disco vía `MiniaturaProducto` |

La regla no cambia: **una tarea, un widget**. Que no quepa en `share2` no
autoriza a tener tres copias con nombres distintos.

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
