# tablas/ — Visualización de colecciones

`lib/frontend/share2/tablas/`

Widgets para mostrar listas y colecciones de datos en formato tabular. El widget principal es `TablaGenerica`, que recibe la definición de columnas de forma dinámica para adaptarse a cualquier módulo.

---

## Widgets previstos

| Widget | Archivo | Estado |
|---|---|---|
| `TablaGenerica` | `tabla_generica.dart` | Pendiente |
| `ColumnaTabla` | `columna_tabla.dart` | Pendiente |
| `FilaTabla` | `fila_tabla.dart` | Pendiente |
| `PaginacionWidget` | `paginacion_widget.dart` | Pendiente |
| `EstadoVacioWidget` | `estado_vacio_widget.dart` | Pendiente |

---

## Criterio para agregar un widget nuevo

Los widgets de esta carpeta solo definen la presentación. Los datos, el orden y el filtrado los reciben como parámetros desde el controlador del módulo.
