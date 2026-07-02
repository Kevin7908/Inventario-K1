# inputs/ — Captura de datos

`lib/frontend/share2/inputs/`

Widgets para formularios y entrada de datos. Aplican el estilo visual del proyecto de forma consistente en todos los módulos.

---

## Widgets previstos

| Widget | Archivo | Estado |
|---|---|---|
| `CampoTexto` | `campo_texto.dart` | Pendiente |
| `CampoMoneda` | `campo_moneda.dart` | Pendiente |
| `SelectorWidget` | `selector_widget.dart` | Pendiente |
| `CheckboxApp` | `checkbox_app.dart` | Pendiente |

---

## Criterio para agregar un input nuevo

Un input en esta carpeta debe ser reutilizable en cualquier formulario del proyecto. Si un campo tiene validaciones o comportamiento específico de un módulo (ej. validar que un código de producto no exista), esa lógica vive en el controlador del módulo, no en el widget.
