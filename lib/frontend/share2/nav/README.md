# nav/ — Navegación

`lib/frontend/share2/nav/`

Widgets y modelos de datos para la navegación principal de la aplicación. El componente central es `BarraLateral`, que ensambla todos los demás.

---

## Widgets

| Widget | Archivo | Estado |
|---|---|---|
| `LogoSidebar` | `logo_sidebar.dart` | Implementado |
| `SeccionNav` | `seccion_nav.dart` | Implementado |
| `ItemNav` | `item_nav.dart` | Implementado |
| `SeparadorNav` | `separador_nav.dart` | Implementado |
| `BarraLateral` | `barra_lateral.dart` | Implementado |

## Modelos de datos

| Clase | Archivo | Descripción |
|---|---|---|
| `ItemNavDato` | `item_nav_dato.dart` | Datos de un ítem: ícono, etiqueta, ruta, callback, badge |
| `SeccionNavDato` | `seccion_nav_dato.dart` | Datos de una sección: título y lista de ítems |

---

## Cómo usar BarraLateral

```dart
BarraLateral(
  rutaActiva: '/categorias',
  secciones: [
    SeccionNavDato(
      titulo: 'Principal',
      items: [
        ItemNavDato(
          icono: Icons.dashboard_outlined,
          etiqueta: 'Dashboard',
          ruta: '/dashboard',
          alPresionar: () => Get.toNamed('/dashboard'),
        ),
        ItemNavDato(
          icono: Icons.point_of_sale_outlined,
          etiqueta: 'Punto de venta',
          ruta: '/venta',
          alPresionar: () => Get.toNamed('/venta'),
        ),
      ],
    ),
    SeccionNavDato(
      titulo: 'Inventario',
      items: [
        ItemNavDato(
          icono: Icons.inventory_2_outlined,
          etiqueta: 'Productos',
          ruta: '/productos',
          alPresionar: () => Get.toNamed('/productos'),
        ),
        ItemNavDato(
          icono: Icons.label_outlined,
          etiqueta: 'Categorías',
          ruta: '/categorias',
          alPresionar: () => Get.toNamed('/categorias'),
        ),
      ],
    ),
  ],
  itemsInferiores: [
    ItemNavDato(
      icono: Icons.settings_outlined,
      etiqueta: 'Configuración',
      ruta: '/configuracion',
      alPresionar: () => Get.toNamed('/configuracion'),
    ),
    ItemNavDato(
      icono: Icons.logout_outlined,
      etiqueta: 'Salir',
      ruta: '',
      alPresionar: () => Get.offAllNamed('/login'),
    ),
  ],
)
```

---

## Notas

- `BarraLateral` tiene ancho fijo de **240px**. El layout de pantalla lo posiciona el feature, no el widget.
- El ítem activo se determina comparando `rutaActiva` con `ItemNavDato.ruta`. El controlador del módulo es responsable de pasar la ruta correcta.
- `BadgeContador` (el círculo rojo con número) vive en `feedback/` porque es reutilizable fuera del sidebar.
