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

El punto de entrada visual de la app después del login. Contiene
`LayoutPrincipal`, que arma el sidebar izquierdo y el `IndexedStack` de vistas.

Quién decide si se ve el login o la app es `PortalSesion`, en
`features/autenticacion/vista/`: es lo que `main.dart` pone como `home`.

→ Ver [`layout/README.md`](layout/README.md)

---

## `features/`

Cada módulo del negocio tiene su propia carpeta. Las vistas de un módulo no importan nada de la carpeta de otro módulo — se comunican a través de `share2` y los repositorios del backend.

| Carpeta | Módulo |
|---|---|
| `autenticacion/` | Inicio de sesión, alta del primer administrador, recuperación de contraseña, cuentas y sus permisos |
| `bitacora/` | Quién hizo qué, y cuándo. Solo la ve quien tenga `BITACORA_VER` |
| `categorias/` | Categorías de productos |
| `clientes/` | Gestión de clientes y de las motos de cada uno |
| `configuracion/` | Ajustes de la aplicación |
| `cotizaciones/` | Cotizaciones de venta |
| `deudores/` | Cuentas por cobrar |
| `especializacion/` | Especializaciones de técnicos |
| `inventario/` | Movimientos de stock: el kardex del taller, el panel de la ficha de producto y la entrada por compra |
| `motos/` | Registro de motos |
| `ordenes/` | Órdenes de servicio: listado y editor |
| `pos/` | Punto de venta (mostrador) |
| `productos/` | Inventario de productos |
| `proveedores/` | Gestión de proveedores |
| `reservas/` | Reservas de productos |
| `servicios/` | Catálogo de servicios del taller |
| `tecnicos/` | Técnicos del taller |
| `unidades_medida/` | Unidades de medida |
| `ventas/` | Historial de ventas: qué se vendió, cuándo y quién lo cobró, y desde dónde se devuelve o se anula |

> **Facturación se borró el 21/08/2026.** Órdenes y servicios subieron un
> nivel, y el backend de las ventas de mostrador —las tablas `ventas` y
> `venta_detalles`, que el POS sigue escribiendo— vive en
> `backend/features/pos/`. La carpeta `ventas/` volvió el 25/08/2026 como
> historial de solo lectura, y el 26/08/2026 ganó lo único que se le hace a una
> factura emitida: **deshacerla**. Devolver una parte o anularla entera, las dos
> detrás de `POS_ANULAR`. Lo que sigue sin existir es armar una factura a mano:
> para eso está el POS.

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

Código de la versión anterior. **No se toca, no se extiende.** Existe solo como
referencia histórica. Todo trabajo nuevo va en `share2/`.

Desde que `autenticacion` se migró, **ningún archivo fuera de `share/` importa
nada de `share/`**: la carpeta quedó huérfana. Borrarla entera es una decisión
aparte, no un descuido —está anotada en `DEUDA_TECNICA.md`—.

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
  | `PanelMovimientosProducto`, `DialogoEntradaCompra` | `inventario/widgets/` | productos |
  | `PanelCategoriasCatalogo` | `categorias/widgets/` | productos, POS, cotizaciones, órdenes |
  | `catalogoCategoriasProvider`, `catalogoServiciosProvider` | su módulo | quien arme un documento |

  La prueba es la de siempre: **si hay dos widgets con la misma tarea y
  distinto nombre, sobra uno**. Antes de escribir uno nuevo, mirar `share2/`,
  y después el módulo dueño de ese dato.
- Un widget de `share2/` nunca importa de `features/`.
- `layout/` puede importar de `features/` y de `share2/`, pero no al revés.
- El frontend importa de `lib/backend/` **solo modelos y enums** —`Producto`,
  `EstadoOrden`, `MetodoPago`, `Permiso`—, nunca una base de datos ni un
  repositorio a mano: al repositorio se llega por su provider de Riverpod.
- **Para esconder algo según el permiso, `SiPuede`** —de
  `features/autenticacion/widgets/`—. Es una línea por compuerta:

  ```dart
  SiPuede(
    permiso: Permiso.productosEliminar,
    child: BotonDestructivo(etiqueta: 'Eliminar', alPresionar: _borrar),
  )
  ```

  Esconder un botón es orden, no control: la compuerta que impide de verdad
  está en el repositorio (`CLAUDE.md` §7 bis).
