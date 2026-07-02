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
| `clientes/` | Gestión de clientes |
| `configuracion/` | Ajustes de la aplicación |
| `cotizaciones/` | Cotizaciones de venta |
| `deudores/` | Cuentas por cobrar |
| `especializacion/` | Especializaciones de técnicos |
| `motos/` | Registro de motos |
| `productos/` | Inventario de productos |
| `proveedores/` | Gestión de proveedores |
| `reservas/` | Reservas de productos |
| `tecnicos/` | Técnicos del taller |
| `unidades_medida/` | Unidades de medida |
| `ventas/` | Punto de venta, órdenes y facturas |

---

## `share2/`

Biblioteca de widgets y tokens de diseño reutilizables. Todo componente visual que aparece en más de un módulo vive aquí.

| Carpeta | Contenido |
|---|---|
| `temas/` | Colores (`ColoresApp`) y tipografía (`TipografiaApp`) |
| `nav/` | Sidebar, ítems de navegación y modelos de datos |
| `botones/` | Botones primario, secundario, destructivo, con carga |
| `inputs/` | Campos de texto, moneda, selectores, checkboxes |
| `tablas/` | Tabla genérica, paginación, estado vacío |
| `cards/` | Tarjetas, paneles y contenedores modales |
| `feedback/` | Badges, snackbars, loaders, diálogos de confirmación |

→ Ver [`share2/README.md`](share2/README.md)

---

## `share/` (legacy — congelado)

Código de la versión anterior. **No se toca, no se extiende.** Existe solo como referencia histórica. Todo trabajo nuevo va en `share2/`.

---

## Reglas generales

- Un widget de `features/` nunca importa de otro módulo de `features/`.
- Un widget de `share2/` nunca importa de `features/`.
- `layout/` puede importar de `features/` y de `share2/`, pero no al revés.
- Ningún archivo del frontend importa directamente de `lib/backend/` — usa los providers de Riverpod.
