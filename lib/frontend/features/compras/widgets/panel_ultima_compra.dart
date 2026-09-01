import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/compras/modelo/compra_item.dart';
import '../../../../core/formato.dart';
import '../../../share/share.dart';
import '../provider/compras_providers.dart';
import 'dialogo_detalle_compra.dart';

/// «Última compra hace 12 días, a $6.500 — Repuestos JR».
///
/// El bloque que el diseño pedía en la ficha del producto y que el backend no
/// tenía: hasta que existieron las remisiones, lo único que se podía enseñar
/// era `precio_compra`, un número que alguien tecleó una vez.
///
/// Es un `ConsumerWidget` propio para que la ficha entera no se repinte cuando
/// llega la compra; observa solo el producto que le pasan.
///
/// Parámetros:
/// - [productoId]: de qué producto es la ficha.
///
/// Ejemplo:
/// ```dart
/// PanelUltimaCompra(productoId: producto.id!)
/// ```
class PanelUltimaCompra extends ConsumerWidget {
  const PanelUltimaCompra({super.key, required this.productoId});

  final int productoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ultima = ref.watch(ultimaCompraProvider(productoId)).value;

    return PanelSeccion(
      titulo: 'Última compra',
      child: ultima == null
          ? Text(
              'Todavía no se ha comprado con una remisión registrada.',
              style:
                  TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
            )
          : _Resumen(ultima: ultima),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.ultima});

  final UltimaCompra ultima;

  /// Cuánto hace, en palabras. El número solo —«hace 0 días»— se lee mal.
  String get _cuando => switch (ultima.diasDesde) {
        0 => 'hoy',
        1 => 'ayer',
        final dias when dias < 31 => 'hace $dias días',
        _ => 'el ${formatearFecha(ultima.fecha)}',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              formatearPrecio(ultima.costoUnitario),
              style: TipografiaApp.heading3
                  .copyWith(color: ColoresApp.castletonGreen),
            ),
            const SizedBox(width: 8),
            Text(
              'por unidad, $_cuando',
              style:
                  TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FilaDato(
          icono: Icons.local_shipping_outlined,
          texto: '${ultima.proveedorNombre} · '
              '${formatearCantidad(ultima.cantidad)} unidades',
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => DialogoDetalleCompra.mostrar(
              context,
              compraId: ultima.compraId,
            ),
            child: Text(
              'Ver la remisión ${ultima.numero}',
              style: TipografiaApp.enlace(TipografiaApp.caption),
            ),
          ),
        ),
      ],
    );
  }
}
