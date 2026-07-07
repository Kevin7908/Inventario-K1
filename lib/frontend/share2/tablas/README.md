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
| `PaginacionWidget` | `paginacion_widget.dart` | Implementado |
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

## Cómo usar PaginacionWidget

`TablaGenerica` no pagina ni virtualiza filas internamente: pinta exactamente los `items` que recibe. Para que la tabla se mantenga liviana con colecciones grandes (productos, ventas, órdenes), el controlador del módulo debe recortar la lista a una página antes de pasarla, y `PaginacionWidget` se encarga de la navegación entre páginas.

```dart
final inicio = paginaActual * itemsPorPagina;
final itemsPagina = items.skip(inicio).take(itemsPorPagina).toList();

Column(
  children: [
    Expanded(
      child: TablaGenerica<Producto>(
        items: itemsPagina,
        columnas: columnas,
      ),
    ),
    PaginacionWidget(
      paginaActual: paginaActual,
      totalPaginas: (items.length / itemsPorPagina).ceil(),
      totalItems: items.length,
      itemsPorPagina: itemsPorPagina,
      alCambiarPagina: (p) => controlador.irAPagina(p),
    ),
  ],
)
```

- `paginaActual` es 0-based; `PaginacionWidget` muestra "Página N de M" en base 1.
- `totalItems` e `itemsPorPagina` son opcionales: si se pasan ambos, se muestra el rango ("Mostrando 1–20 de 97"); si no, solo se muestra el indicador de página.
- El recorte (`skip`/`take`) es responsabilidad del controlador del módulo, no de `TablaGenerica` ni de `PaginacionWidget` — ninguno de los dos conoce la lista completa.

---

## Regla de rendimiento: nunca pasar la lista completa sin paginar

`TablaGenerica` construye todas las filas de `items` de una sola vez (no usa `ListView.builder`). Esto es intencional para colecciones ya paginadas (decenas de filas), pero significa que **pasarle cientos o miles de ítems sin paginar construye ese árbol completo de golpe** y vuelve la pantalla pesada. Cualquier pantalla que liste una colección potencialmente grande debe usar el patrón de `PaginacionWidget` de arriba antes de integrarse.

---

## Criterio para agregar un widget nuevo

Los widgets de esta carpeta solo definen la presentación. Los datos, el orden y el filtrado los reciben como parámetros desde el controlador del módulo.
