# cards/ — Contenedores de información

`lib/frontend/share2/cards/`

Widgets para agrupar y presentar información con estilos consistentes. Se usan como contenedores visuales, no como widgets de acción.

---

## Widgets previstos

| Widget | Archivo | Estado |
|---|---|---|
| `TarjetaInfo` | `tarjeta_info.dart` | Pendiente |
| `PanelSeccion` | `panel_seccion.dart` | Implementado |
| `ContenedorModal` | `contenedor_modal.dart` | Pendiente |

---

## Cómo usar PanelSeccion

```dart
PanelSeccion(
  titulo: 'Datos del negocio',
  child: Column(
    children: [
      CampoTexto(etiqueta: 'Nombre del taller', controlador: _nombreController),
    ],
  ),
)

// Con ícono — secciones de un formulario largo (ej. "Nuevo producto")
PanelSeccion(
  titulo: 'Información general',
  icono: Icons.info_outline,
  child: Column(children: [...]),
)
```

---

## Criterio para agregar un widget nuevo

Un widget de esta carpeta es un contenedor: recibe contenido como parámetro (`child` o `children`) y aplica estilos. No decide qué mostrar adentro.
