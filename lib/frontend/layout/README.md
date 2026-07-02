# layout/ — App Shell

`lib/frontend/layout/`

Contiene el único widget que define la estructura global de la aplicación: sidebar izquierdo + área de contenido. Es el punto de entrada visual luego del login.

---

## Archivos

| Archivo | Clase | Descripción |
|---|---|---|
| `layout_principal.dart` | `LayoutPrincipal` | App shell completo con sidebar y toggle |

---

## `LayoutPrincipal`

`StatefulWidget` que gestiona dos estados:

| Estado | Tipo | Descripción |
|---|---|---|
| `_sidebarExpandido` | `bool` | Controla si el sidebar está visible o colapsado |
| `_indiceActivo` | `int` | Índice de la vista activa en el `IndexedStack` |

### Estructura visual

```
Scaffold
└── Row
    ├── AnimatedContainer (sidebar)          ← ancho 240 → 0 con animación
    │   └── BarraLateral (share2)
    └── Expanded (contenido)
        ├── _TopBar                          ← botón de toggle del sidebar
        ├── Divider
        └── IndexedStack                     ← todas las vistas de la app
```

### Cómo agrega una vista nueva

1. Agregar la ruta en la lista `_rutas` (línea ~40).
2. Agregar el widget de vista en el mismo índice dentro del `IndexedStack` (línea ~170).
3. Agregar el `ItemNavDato` correspondiente en `_secciones` o `_itemsInferiores`.

**El orden en `_rutas` y en `IndexedStack` debe ser idéntico.** Si se desincroniza, la navegación apunta a la vista equivocada.

### Vistas registradas

| Índice | Ruta | Vista |
|---|---|---|
| 0 | `/dashboard` | `_PlaceholderVista` |
| 1 | `/venta` | `VentasVista` |
| 2 | `/productos` | `ProductosVista` |
| 3 | `/categorias` | `CategoriasVista` |
| 4 | `/unidades-medida` | `UnidadesMedidaVista` |
| 5 | `/proveedores` | `ProveedoresVista` |
| 6 | `/motos` | `MotosVista` |
| 7 | `/cotizaciones` | `CotizacionesVista` |
| 8 | `/reservas` | `ReservasVista` |
| 9 | `/tecnicos` | `TecnicosVista` |
| 10 | `/especializaciones` | `EspecializacionesVista` |
| 11 | `/clientes` | `ClientesVista` |
| 12 | `/deudores` | `DeudoresVista` |

### Widgets privados

| Widget | Descripción |
|---|---|
| `_TopBar` | Barra superior con el botón de toggle del sidebar. Altura fija 52px. |
| `_PlaceholderVista` | Vista temporal para secciones aún no implementadas (Dashboard). |

---

## Qué NO va en layout/

- Widgets reutilizables → van en `share2/`
- Lógica de negocio → va en el controlador del módulo correspondiente
- Vistas de módulos → van en `features/<modulo>/vista/`
- Lógica de autenticación → la pantalla de login no pasa por `LayoutPrincipal`
