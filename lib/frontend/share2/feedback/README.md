# feedback/ — Respuesta visual al usuario

`lib/frontend/share2/feedback/`

Widgets para comunicar el resultado de las acciones del usuario. **Todos los módulos del proyecto deben usar estos widgets** para garantizar que errores, éxitos y estados de carga se vean y se comporten igual en toda la aplicación.

---

## Widgets

| Widget | Archivo | Estado |
|---|---|---|
| `BadgeContador` | `badge_contador.dart` | Implementado |
| `IconoNotificaciones` | `icono_notificaciones.dart` | Implementado |
| `SnackbarApp` | `snackbar_app.dart` | Pendiente |
| `LoaderPantalla` | `loader_pantalla.dart` | Pendiente |
| `DialogoConfirmacion` | `dialogo_confirmacion.dart` | Implementado |
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

## `IconoNotificaciones`

Campana con un punto rojo cuando hay notificaciones sin leer. No muestra cantidad — para eso está `BadgeContador`.

```dart
// Sin notificaciones pendientes
IconoNotificaciones(alPresionar: () {})

// Con punto rojo
IconoNotificaciones(tieneNotificaciones: true, alPresionar: () => controlador.abrirNotificaciones())
```

Parámetros:
- `alPresionar` (VoidCallback, requerido) — acción al tocar la campana.
- `tieneNotificaciones` (bool, opcional) — muestra el punto rojo. Por defecto `false`.

---

## `DialogoConfirmacion`

Pide confirmación antes de una acción irreversible (eliminar, anular). Usa `BotonDestructivo` para el botón de confirmar.

```dart
final confirmado = await DialogoConfirmacion.mostrar(
  context,
  titulo: '¿Eliminar "Litro"?',
  mensaje: 'Esta acción no se puede deshacer.',
);
if (confirmado == true) controlador.eliminar(id);
```

Parámetros:
- `titulo` (String, requerido) — pregunta o encabezado del diálogo.
- `mensaje` (String?, opcional) — texto adicional debajo del título.
- `textoConfirmar` / `textoCancelar` (String, opcional) — por defecto `'Eliminar'` / `'Cancelar'`.

El método estático `mostrar` devuelve `true` si el usuario confirmó, o `null`/`false` si canceló o cerró el diálogo.

---

## Criterio para agregar un widget nuevo

Si un módulo necesita mostrar un estado, un error o una confirmación de forma distinta a los widgets existentes, primero se evalúa si se puede resolver con un parámetro adicional en uno de los widgets actuales. Solo si el caso es genuinamente diferente se crea un widget nuevo aquí.
