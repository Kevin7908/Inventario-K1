# inputs/ — Captura de datos

`lib/frontend/share2/inputs/`

Widgets para formularios y entrada de datos. Aplican el estilo visual del proyecto de forma consistente en todos los módulos.

---

## Widgets previstos

| Widget | Archivo | Estado |
|---|---|---|
| `CampoTexto` | `campo_texto.dart` | Implementado |
| `CampoMoneda` | `campo_moneda.dart` | Pendiente |
| `SelectorWidget` | `selector_widget.dart` | Implementado |
| `CheckboxApp` | `checkbox_app.dart` | Pendiente |
| `BarraBusqueda` | `barra_busqueda.dart` | Implementado |

---

## Cómo usar CampoTexto y SelectorWidget

```dart
CampoTexto(
  etiqueta: 'Nombre del taller',
  controlador: _nombreController,
)

SelectorWidget<String>(
  etiqueta: 'Moneda',
  valor: _moneda,
  opciones: const ['COP', 'USD'],
  constructorEtiqueta: (v) => v == 'COP' ? 'Peso colombiano (COP \$)' : 'Dólar (USD \$)',
  alCambiar: (v) => setState(() => _moneda = v),
)
```

- `CampoTexto` recibe un `TextEditingController` — el ciclo de vida del controller (crear/dispose) es responsabilidad del `StatefulWidget` que lo usa.
- `SelectorWidget<T>` es genérico: funciona con cualquier tipo de opción (`String`, `enum`, modelos), siempre que se le pase cómo convertir cada una a texto.

---

## Cómo usar BarraBusqueda

A diferencia de `CampoTexto`, no lleva etiqueta arriba: es un input autocontenido con ícono de lupa, pensado para filtrar listas y tablas (también usado en la barra superior de la topbar).

```dart
BarraBusqueda(
  controlador: _busquedaController,
  placeholder: 'Buscar unidad...',
  alCambiar: (texto) => controlador.buscar(texto),
  ancho: 320,
)
```

- `ancho` es opcional: si no se define, el campo ocupa todo el ancho disponible de su contenedor (útil dentro de un `Row` con `Expanded`, como la barra superior).

---

## Criterio para agregar un input nuevo

Un input en esta carpeta debe ser reutilizable en cualquier formulario del proyecto. Si un campo tiene validaciones o comportamiento específico de un módulo (ej. validar que un código de producto no exista), esa lógica vive en el controlador del módulo, no en el widget.
