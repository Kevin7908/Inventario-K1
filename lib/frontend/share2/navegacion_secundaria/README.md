# navegacion_secundaria/ — Navegación por pestañas dentro de una pantalla

`lib/frontend/share2/navegacion_secundaria/`

Widgets para cambiar entre secciones dentro de una misma pantalla mediante pestañas (ej. General | Unidades de medida | Especializaciones | Servicios en Configuración).

Esta carpeta es distinta de [`nav/`](../nav/README.md), que cubre exclusivamente el sidebar principal de la aplicación. Aquí vive la navegación secundaria, la que ocurre *dentro* del contenido de una pantalla.

---

## Widgets previstos

| Widget | Archivo | Estado |
|---|---|---|
| `BarraTabsSecundaria` | `barra_tabs_secundaria.dart` | Implementado |

## Modelos de datos

| Clase | Archivo | Descripción |
|---|---|---|
| `TabSecundariaDato` | `tab_secundaria_dato.dart` | Datos de una pestaña: etiqueta y callback |

---

## Ejemplo de uso

```dart
BarraTabsSecundaria(
  tabs: [
    TabSecundariaDato(etiqueta: 'General', alPresionar: () => controlador.cambiarTab(0)),
    TabSecundariaDato(etiqueta: 'Unidades de medida', alPresionar: () => controlador.cambiarTab(1)),
    TabSecundariaDato(etiqueta: 'Especializaciones', alPresionar: () => controlador.cambiarTab(2)),
    TabSecundariaDato(etiqueta: 'Servicios', alPresionar: () => controlador.cambiarTab(3)),
  ],
  indiceActivo: controlador.tabActivo,
)
```

- La pestaña activa se determina comparando `indiceActivo` con la posición de cada `TabSecundariaDato`. El controlador del módulo es responsable de mantener ese estado.
- El contenido que se muestra debajo de las pestañas lo decide la feature, no este widget.

---

## Criterio para agregar un widget nuevo

Antes de crear un widget aquí, verificar que el caso no se resuelve con un parámetro de `BarraTabsSecundaria` (ej. cantidad de tabs, ancho). Solo se crea un widget nuevo si la interacción es genuinamente distinta (por ejemplo, tabs con ícono en vez de solo texto).
