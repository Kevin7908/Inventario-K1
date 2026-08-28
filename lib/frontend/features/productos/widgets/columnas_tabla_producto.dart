import 'package:flutter/material.dart';

import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../../core/formato.dart';
import '../../../share/share.dart';
import '../vista/producto_vista.dart';
import 'badget_estado_stock_widget.dart';

/// Columnas de la tabla de productos.
///
/// Vive aquí y no dentro de una vista para que el catálogo de Productos y el
/// detalle de una categoría muestren **exactamente** las mismas columnas: si
/// se agrega una, aparece en los dos sitios sin tener que acordarse.
///
/// - [mostrarCategoria]: en el detalle de una categoría sobra, porque todas
///   las filas son de la misma.
List<ColumnaTabla<Producto>> columnasTablaProducto({
  bool mostrarCategoria = true,
}) {
  return [
    ColumnaTabla(
      titulo: 'Producto',
      flex: 5,
      constructor: (p) => CeldaProducto(producto: p),
    ),
    if (mostrarCategoria)
      ColumnaTabla(
        titulo: 'Categoría',
        flex: 2,
        constructor: (p) => Text(
          p.categoriaNombre ?? '—',
          style: TipografiaApp.caption.copyWith(fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ColumnaTabla(
      titulo: 'Precio',
      flex: 2,
      constructor: (p) => Text(
        formatearPrecio(p.precioVenta),
        style: TipografiaApp.cuerpoMedium.copyWith(
          color: ColoresApp.castletonGreen,
        ),
      ),
    ),
    ColumnaTabla(
      titulo: 'Stock',
      flex: 2,
      constructor: (p) => BadgeEstadoStock(estado: p.estadoStock),
    ),
    ColumnaTabla(
      titulo: 'Ubicación',
      flex: 2,
      constructor: (p) => Text(
        p.ubicacionBodega ?? '—',
        style: TipografiaApp.caption,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    ColumnaTabla(
      titulo: '',
      ancho: 32,
      alineacion: Alignment.centerRight,
      constructor: (_) => const Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: ColoresApp.textDisabled,
      ),
    ),
  ];
}

/// Celda principal: miniatura + nombre + SKU monoespaciado.
class CeldaProducto extends StatelessWidget {
  const CeldaProducto({super.key, required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MiniaturaProducto(rutaImagen: producto.imagenUrl),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                producto.nombre,
                style: TipografiaApp.cuerpoMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                producto.sku,
                style: TipografiaApp.monoespaciada(
                  TipografiaApp.caption.copyWith(
                    fontSize: 12,
                    color: ColoresApp.textDisabled,
                  ),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
