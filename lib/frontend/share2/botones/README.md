# botones/ — Acciones del usuario

`lib/frontend/share2/botones/`

Widgets para todas las acciones que puede ejecutar el usuario. Se diferencian por jerarquía visual y tipo de consecuencia de la acción.

---

## Widgets previstos

| Widget | Archivo | Estado |
|---|---|---|
| `BotonPrimario` | `boton_primario.dart` | Pendiente |
| `BotonSecundario` | `boton_secundario.dart` | Pendiente |
| `BotonDestructivo` | `boton_destructivo.dart` | Pendiente |
| `BotonIcono` | `boton_icono.dart` | Pendiente |
| `BotonConCarga` | `boton_con_carga.dart` | Pendiente |

---

## Criterio para agregar un botón nuevo

Antes de crear un widget aquí, verificar que no es un caso cubierto por uno de los botones existentes con un parámetro diferente. Por ejemplo, deshabilitar un botón no es un widget nuevo, es `alPresionar: null`.
