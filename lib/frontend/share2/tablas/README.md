# tablas/ — Visualización de colecciones

`lib/frontend/share2/tablas/`

Widgets para mostrar listas y colecciones de datos en formato tabular. El widget principal es `TablaGenerica`, que recibe la definición de columnas de forma dinámica para adaptarse a cualquier módulo.

---

## Widgets previstos

| Widget | Archivo | Estado |
|---|---|---|
| `TablaGenerica` | `tabla_generica.dart` | Implementado |
| `ColumnaTabla` | `columna_tabla.dart` | Implementado |
| `FilaTabla` | `fila_tabla.dart` | Implementado |
| `PaginacionWidget` | `paginacion_widget.dart` | Pendiente |
| `EstadoVacioWidget` | `estado_vacio_widget.dart` | Pendiente |

---

## Cómo usar TablaGenerica

```dart
TablaGenerica<UnidadMedida>(
  items: unidades,
  columnas: [
    ColumnaTabla(
      titulo: 'Unidad',
      flex: 2,
      constructor: (u) => Text(u.nombre, style: TipografiaApp.cuerpoMedium),
    ),
    ColumnaTabla(
      titulo: 'Abreviatura',
      constructor: (u) => Text(u.abreviatura),
    ),
    ColumnaTabla(
      titulo: 'Uso típico',
      flex: 3,
      constructor: (u) => Text(u.descripcion ?? '—'),
    ),
  ],
)
```

- El encabezado se pinta en `TipografiaApp.overline` sobre `ColoresApp.bgCard`, con un `Divider` de `ColoresApp.border` entre cada fila.
- `FilaTabla` resalta con `ColoresApp.bgCardHover` en hover y con `ColoresApp.statusSuccessBg` cuando `seleccionada` es `true`.
- Cada `ColumnaTabla` decide el contenido y el estilo de su celda a través de `constructor`; `TablaGenerica` solo arma la grilla.

---

## Criterio para agregar un widget nuevo

Los widgets de esta carpeta solo definen la presentación. Los datos, el orden y el filtrado los reciben como parámetros desde el controlador del módulo.
