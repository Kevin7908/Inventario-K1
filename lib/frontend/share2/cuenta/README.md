# cuenta/ — Sesión del usuario logueado

`lib/frontend/share2/cuenta/`

Widgets para mostrar quién está usando la aplicación en ese momento. Distinta de `nav/` (que es exclusivamente el sidebar) y de `encabezados/` (que es solo título y subtítulo) — esta carpeta existe porque el bloque de cuenta se repite en el encabezado de cada pantalla, junto al título.

---

## Widgets

| Widget | Archivo | Estado |
|---|---|---|
| `AvatarUsuario` | `avatar_usuario.dart` | Implementado |
| `CuentaUsuarioWidget` | `cuenta_usuario_widget.dart` | Implementado |

---

## `AvatarUsuario`

Círculo con las iniciales del usuario.

```dart
AvatarUsuario(iniciales: 'ZM')
AvatarUsuario(iniciales: 'K1', tamano: 32, color: ColoresApp.goGreen)
```

---

## `CuentaUsuarioWidget`

Avatar + nombre + rol del usuario logueado. Se usa típicamente como `acciones` de `EncabezadoPagina`.

```dart
EncabezadoPagina(
  titulo: 'Configuración',
  acciones: CuentaUsuarioWidget(
    nombre: 'Zaim Maulana',
    rol: 'Administrador',
    iniciales: 'ZM',
  ),
)
```

- `nombre`, `rol` e `iniciales` los calcula el módulo que integra el widget (ej. a partir del usuario autenticado). `CuentaUsuarioWidget` no sabe de dónde vienen esos datos.
- `alPresionar` es opcional; si se define, el bloque completo se vuelve tocable (ej. para abrir un menú de "Cerrar sesión").

---

## Criterio para agregar un widget nuevo

Un widget de esta carpeta solo representa la identidad de la sesión activa (quién soy, qué rol tengo). No incluye menús desplegables con lógica de negocio (cerrar sesión, cambiar contraseña) — eso lo arma la feature que lo integra, usando `alPresionar` como punto de entrada.
