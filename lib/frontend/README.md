# frontend/ — Capa de presentación

`lib/frontend/`

Todo lo visual de la aplicación vive aquí. La capa de presentación no contiene lógica de negocio ni acceso a base de datos — eso pertenece a `lib/backend/`.

---

## Estructura

```
frontend/
├── layout/          ← app shell (sidebar + área de contenido)
├── features/        ← vistas y widgets específicos de cada módulo
└── share2/          ← widgets y tokens de diseño reutilizables
```

---

## `layout/`

El punto de entrada visual de la app después del login. Contiene `LayoutPrincipal`, que arma el sidebar izquierdo y el `IndexedStack` de vistas.

→ Ver [`layout/README.md`](layout/README.md)

---

## `features/`

Cada módulo del negocio tiene su propia carpeta. Las vistas de un módulo no importan nada de la carpeta de otro módulo — se comunican a través de `share2` y los repositorios del backend.

| Carpeta | Módulo |
|---|---|
| `autenticacion/` | Login y registro |
| `categorias/` | Categorías de productos |
| `clientes/` | Gestión de clientes y de las motos de cada uno |
| `configuracion/` | Ajustes de la aplicación |
| `cotizaciones/` | Cotizaciones de venta |
| `deudores/` | Cuentas por cobrar |
| `especializacion/` | Especializaciones de técnicos |
| `motos/` | Registro de motos |
| `ordenes/` | Órdenes de servicio: listado y editor |
| `pos/` | Punto de venta (mostrador) |
| `productos/` | Inventario de productos |
| `proveedores/` | Gestión de proveedores |
| `reservas/` | Reservas de productos |
| `servicios/` | Catálogo de servicios del taller |
| `tecnicos/` | Técnicos del taller |
| `unidades_medida/` | Unidades de medida |

> **Facturación se borró el 21/08/2026.** Con ella se fue la carpeta `ventas/`:
> órdenes y servicios subieron un nivel, y el backend de las ventas de
> mostrador —las tablas `ventas` y `venta_detalles`, que el POS sigue
> escribiendo— vive ahora en `backend/features/pos/`.

---

## `share2/`

Biblioteca de widgets y tokens de diseño reutilizables. Todo componente visual que aparece en más de un módulo vive aquí.

| Carpeta | Contenido |
|---|---|
| `temas/` | Colores (`ColoresApp`) y tipografía (`TipografiaApp`) |
| `nav/` | Sidebar, ítems de navegación y modelos de datos |
| `botones/` | Botones primario, secundario, destructivo, de ícono |
| `inputs/` | Campos de texto, fecha, búsqueda, cantidad, atajos |
| `filtros/` | Panel de categorías colapsable y chips de filtro |
| `tablas/` | Tabla genérica, columnas, filas y paginación |
| `cards/` | Tarjetas, paneles, pie de totales |
| `feedback/` | Badges, avisos (`MensajeApp`), diálogos de confirmación |
| `encabezados/`, `navegacion_secundaria/`, `cuenta/` | Encabezado de pantalla, pestañas y usuario logueado |

→ Ver [`share2/README.md`](share2/README.md)

---

## `share/` (legacy — congelado)

Código de la versión anterior. **No se toca, no se extiende.** Existe solo como referencia histórica. Todo trabajo nuevo va en `share2/`.

---

## Reglas generales

- Un módulo de `features/` **no importa las vistas de otro módulo**. Sí puede
  usar sus **piezas de catálogo**, que son las que existen justamente para
  compartirse y no caben en `share2` porque consultan providers o conocen el
  modelo de dominio:

  | Pieza | Vive en | La usan |
  |---|---|---|
  | `GrillaProductosCatalogo` | `productos/widgets/` | POS, cotizaciones, órdenes |
  | `MiniaturaProducto` | `productos/vista/` | las mismas |
  | `PanelCategoriasCatalogo` | `categorias/widgets/` | productos, POS, cotizaciones, órdenes |
  | `catalogoCategoriasProvider`, `catalogoServiciosProvider` | su módulo | quien arme un documento |

  La prueba es la de siempre: **si hay dos widgets con la misma tarea y
  distinto nombre, sobra uno**. Antes de escribir uno nuevo, mirar `share2/`,
  y después el módulo dueño de ese dato.
- Un widget de `share2/` nunca importa de `features/`.
- `layout/` puede importar de `features/` y de `share2/`, pero no al revés.
- El frontend importa de `lib/backend/` **solo modelos y enums** —`Producto`,
  `EstadoOrden`, `MetodoPago`—, nunca una base de datos ni un repositorio a
  mano: al repositorio se llega por su provider de Riverpod.
