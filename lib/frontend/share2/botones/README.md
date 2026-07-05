# botones/ — Acciones del usuario

`lib/frontend/share2/botones/`

Widgets para todas las acciones que puede ejecutar el usuario. Se diferencian por jerarquía visual y tipo de consecuencia de la acción.

---

## Widgets previstos

| Widget | Archivo | Estado |
|---|---|---|
| `BotonPrimario` | `boton_primario.dart` | Implementado |
| `BotonSecundario` | `boton_secundario.dart` | Pendiente |
| `BotonDestructivo` | `boton_destructivo.dart` | Pendiente |
| `BotonIcono` | `boton_icono.dart` | Pendiente |
| `BotonConCarga` | `boton_con_carga.dart` | Pendiente |

---

## `BotonPrimario`

Botón de fondo `ColoresApp.goGreen` con texto e ícono en `ColoresApp.textOnPrimary`.

```dart
// Sin ícono
BotonPrimario(
  etiqueta: 'Registrar venta',
  alPresionar: () => controlador.registrar(),
)

// Con ícono opcional
BotonPrimario(
  etiqueta: 'Guardar cambios',
  icono: Icons.check,
  alPresionar: () => controlador.guardar(),
)

// Deshabilitado (alPresionar: null)
BotonPrimario(
  etiqueta: 'Guardar cambios',
  icono: Icons.check,
  alPresionar: null,
)
```

Parámetros:
- `etiqueta` (String, requerido) — texto del botón.
- `alPresionar` (VoidCallback?, requerido) — si es `null`, el botón se muestra atenuado y no responde a toques.
- `icono` (IconData?, opcional) — ícono a la izquierda del texto. Si es `null`, no se muestra ninguno.

---

## Criterio para agregar un botón nuevo

Antes de crear un widget aquí, verificar que no es un caso cubierto por uno de los botones existentes con un parámetro diferente. Por ejemplo, deshabilitar un botón no es un widget nuevo, es `alPresionar: null`, y mostrar o no un ícono es el parámetro `icono` de `BotonPrimario`, no un widget aparte.
