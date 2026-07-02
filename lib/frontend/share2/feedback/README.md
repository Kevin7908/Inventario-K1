# feedback/ — Respuesta visual al usuario

`lib/frontend/share2/feedback/`

Widgets para comunicar el resultado de las acciones del usuario. **Todos los módulos del proyecto deben usar estos widgets** para garantizar que errores, éxitos y estados de carga se vean y se comporten igual en toda la aplicación.

---

## Widgets

| Widget | Archivo | Estado |
|---|---|---|
| `BadgeContador` | `badge_contador.dart` | Implementado |
| `SnackbarApp` | `snackbar_app.dart` | Pendiente |
| `LoaderPantalla` | `loader_pantalla.dart` | Pendiente |
| `DialogoConfirmacion` | `dialogo_confirmacion.dart` | Pendiente |
| `IndicadorEstado` | `indicador_estado.dart` | Pendiente |

---

## `BadgeContador`

Badge circular con número. Se usa cuando un ítem tiene conteos pendientes visibles (órdenes, notificaciones, mensajes).

```dart
// Badge rojo por defecto
BadgeContador(cantidad: 5)

// Badge con color personalizado
BadgeContador(cantidad: 12, color: ColoresApp.statusWarning)

// No renderiza nada si cantidad es 0
BadgeContador(cantidad: 0) // → SizedBox.shrink()
```

Parámetros:
- `cantidad` (int, requerido) — número a mostrar. Muestra `99+` si supera 99.
- `color` (Color, opcional) — fondo del badge. Por defecto `ColoresApp.statusDanger`.

---

## Criterio para agregar un widget nuevo

Si un módulo necesita mostrar un estado, un error o una confirmación de forma distinta a los widgets existentes, primero se evalúa si se puede resolver con un parámetro adicional en uno de los widgets actuales. Solo si el caso es genuinamente diferente se crea un widget nuevo aquí.
