# layout/ — App Shell

`lib/frontend/layout/`

Contiene el único widget que define la estructura global de la aplicación: sidebar izquierdo + área de contenido. Es el punto de entrada visual luego del login.

---

## Archivos

| Archivo | Clase | Descripción |
|---|---|---|
| `layout_principal.dart` | `LayoutPrincipal` | App shell completo con sidebar |
| `encabezado_con_cuenta.dart` | `EncabezadoConCuenta` | `EncabezadoPagina` con la sesión activa a la derecha |

---

## `LayoutPrincipal`

`ConsumerStatefulWidget` que gestiona dos estados:

| Estado | Tipo | Descripción |
|---|---|---|
| `_indiceActivo` | `int` | Índice de la vista activa en el `IndexedStack` |
| `_visitadas` | `Set<int>` | Vistas ya abiertas. Las demás quedan como un hueco vacío en vez de construirse al arrancar |

Es `Consumer` por dos cosas:

- el ítem **Salir** del pie del sidebar, que pide confirmación y llama a
  `sesionProvider.salir()` —como la sesión no se guarda en disco, salir obliga
  a volver a teclear la contraseña—;
- **el filtro de permisos**: `_permisoPorRuta` dice qué permiso hace falta para
  ver cada sección, y `_seccionesVisibles` las recorta en cada `build`. Se
  filtra ahí y no una sola vez porque los permisos cambian en vivo: quitarle el
  mostrador a un cajero tiene que notarse sin que vuelva a entrar. Los
  `ItemNavDato` que sobreviven son las mismas instancias, así que sus `ItemNav`
  no se reconstruyen.

`/dashboard` no lleva permiso a propósito: es donde aterriza quien no tiene
ninguna otra sección, y dejar a alguien sin sitio donde caer es peor que
enseñarle un resumen vacío.

### Estructura visual

```
Scaffold
└── Row
    ├── BarraLateral (share)                ← ancho fijo 240
    └── Expanded
        └── RepaintBoundary
            └── IndexedStack                 ← las vistas ya visitadas
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
| 1 | `/venta` | `PuntoVentaVista` |
| 2 | `/productos` | `ProductosVista` |
| 3 | `/categorias` | `CategoriasVista` |
| 4 | `/proveedores` | `ProveedoresVista` |
| 5 | `/ordenes` | `OrdenesVista` |
| 6 | `/cotizaciones` | `CotizacionesVista` |
| 7 | `/reservas` | `ReservasVista` |
| 8 | `/tecnicos` | `TecnicosVista` |
| 9 | `/clientes` | `ClientesVista` |
| 10 | `/deudores` | `DeudoresVista` |
| 11 | `/configuracion` | `ConfiguracionVista` |

Unidades de medida, Especializaciones, Servicios y Motos ya no son secciones
del sidebar: son pestañas de Configuración.

### Widgets privados

| Widget | Descripción |
|---|---|
| `_PlaceholderVista` | Vista temporal para secciones aún no implementadas (Dashboard). |

---

## `EncabezadoConCuenta`

`ConsumerWidget` que observa `usuarioEnSesionProvider` y pinta el nombre, las
iniciales y el rol de quien está usando la app como acciones de
`EncabezadoPagina`.

Vive aquí y no en `share/` porque conecta un widget presentacional con el
estado real de la sesión. Es `Consumer` **él mismo**, no la pantalla que lo
usa: cuando cambia el usuario, lo único que se reconstruye es esta fila.

---

## Qué NO va en layout/

- Widgets reutilizables → van en `share/`
- Lógica de negocio → va en el controlador del módulo correspondiente
- Vistas de módulos → van en `features/<modulo>/vista/`
- Lógica de autenticación → quien decide si se ve el login o la app es
  `PortalSesion`, en `features/autenticacion/vista/`. `LayoutPrincipal` solo
  existe cuando ya hay sesión abierta.
