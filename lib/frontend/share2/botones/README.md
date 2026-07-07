# botones/ — Acciones del usuario

`lib/frontend/share2/botones/`

Widgets para todas las acciones que puede ejecutar el usuario. Se diferencian por jerarquía visual y tipo de consecuencia de la acción.

---

## Widgets previstos

| Widget | Archivo | Estado |
|---|---|---|
| `BotonPrimario` | `boton_primario.dart` | Implementado |
| `BotonSecundario` | `boton_secundario.dart` | Pendiente |
| `BotonDestructivo` | `boton_destructivo.dart` | Implementado |
| `BotonIcono` | `boton_icono.dart` | Implementado |
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

## `BotonDestructivo`

Botón de fondo `ColoresApp.statusDanger` con texto e ícono en `ColoresApp.textOnPrimary`. Se usa para acciones irreversibles (Eliminar, Anular), típicamente como botón de confirmación dentro de `DialogoConfirmacion`.

```dart
BotonDestructivo(
  etiqueta: 'Eliminar',
  icono: Icons.delete_outline_rounded,
  alPresionar: () => controlador.eliminar(id),
)
```

Parámetros:
- `etiqueta` (String, requerido) — texto del botón.
- `alPresionar` (VoidCallback?, requerido) — si es `null`, el botón se muestra atenuado y no responde a toques.
- `icono` (IconData?, opcional) — ícono a la izquierda del texto.

---

## `BotonIcono`

Botón compacto de un solo ícono, sin texto ni fondo propio (fondo transparente + hover sutil). Se usa para acciones dentro de espacios angostos, típicamente en la columna de acciones de una fila de tabla.

```dart
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    BotonIcono(
      icono: Icons.edit_outlined,
      tooltip: 'Editar',
      alPresionar: () => controlador.editar(item),
    ),
    BotonIcono(
      icono: Icons.delete_outline_rounded,
      tooltip: 'Eliminar',
      color: ColoresApp.statusDanger,
      alPresionar: () => controlador.eliminar(item),
    ),
  ],
)
```

Parámetros:
- `icono` (IconData, requerido) — ícono del botón.
- `alPresionar` (VoidCallback?, requerido) — si es `null`, el botón se muestra atenuado y no responde a toques.
- `color` (Color?, opcional) — color del ícono. Por defecto `ColoresApp.textSecondary`.
- `tooltip` (String?, opcional) — texto al mantener el cursor encima.

---

## Criterio para agregar un botón nuevo

Antes de crear un widget aquí, verificar que no es un caso cubierto por uno de los botones existentes con un parámetro diferente. Por ejemplo, deshabilitar un botón no es un widget nuevo, es `alPresionar: null`, y mostrar o no un ícono es el parámetro `icono` de `BotonPrimario`, no un widget aparte.
