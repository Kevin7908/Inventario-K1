import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/compras/modelo/compra_item.dart';
import '../../../../backend/features/compras/modelo/compra_resumen.dart';
import '../../../../core/formato.dart';
import '../../../share/share.dart';
import '../../documentos/provider/documentos_providers.dart';
import '../../documentos/traductores/compra_a_documento.dart';
import '../../documentos/widgets/dialogo_vista_previa.dart';
import '../../productos/widgets/miniatura_linea.dart';
import '../provider/compras_providers.dart';
import 'estado_compra_ui.dart';

/// Un vistazo a la remisión desde fuera del módulo: qué llegó, a cuánto y de
/// quién.
///
/// **Solo lee, pero sí imprime.** Existe para el «ver la remisión COM-0007» de
/// la ficha del producto: corregirla o anularla se hace en su ficha, que es una
/// pantalla entera dentro de Compras y a la que desde aquí no hay cómo navegar.
/// Sacar el papel no cambia nada, así que no hay razón para obligar a dar ese
/// rodeo: es el mismo `documentoDeCompra` que abre el pie de la ficha.
///
/// Ejemplo:
/// ```dart
/// await DialogoDetalleCompra.mostrar(context, compraId: compra.id);
/// ```
class DialogoDetalleCompra extends ConsumerWidget {
  const DialogoDetalleCompra({super.key, required this.compraId});

  final int compraId;

  static Future<void> mostrar(BuildContext context, {required int compraId}) =>
      showDialog<void>(
        context: context,
        builder: (_) => DialogoDetalleCompra(compraId: compraId),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalle = ref.watch(compraDetalleProvider(compraId));

    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: detalle.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AvisoEnLinea(
              mensaje: 'No se pudo abrir la compra: $e',
              tono: TonoAviso.error,
            ),
            data: (compra) => _Contenido(detalle: compra),
          ),
        ),
      ),
    );
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.detalle});

  final CompraDetalle detalle;

  /// El mismo impreso que la ficha de la remisión. El detalle ya está en la
  /// mano —es lo que esta pantalla acaba de pintar—, así que aquí solo falta
  /// el encabezado del taller.
  Future<void> _imprimir(BuildContext context, WidgetRef ref) async {
    try {
      final ajustes = await leerAjustesImpresion(
        ref.read(repositorioConfiguracionProvider),
      );
      if (!context.mounted) return;

      await DialogoVistaPrevia.mostrar(
        context,
        documento: documentoDeCompra(
          compra: detalle,
          negocio: ajustes.negocio,
        ),
        formato: ajustes.formato,
      );
    } catch (e) {
      if (!context.mounted) return;
      MensajeApp.error(context, 'No se pudo abrir la remisión: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compra = detalle.resumen;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(compra.numero, style: TipografiaApp.heading3),
                  const SizedBox(height: 2),
                  Text(
                    '${compra.proveedorNombre} · '
                    '${formatearFecha(compra.fecha)}',
                    style: TipografiaApp.caption
                        .copyWith(color: ColoresApp.textMuted),
                  ),
                ],
              ),
            ),
            BadgeEstadoCompra(estado: compra.estado),
          ],
        ),
        const SizedBox(height: 18),
        FilaCampos(
          hijos: [
            TarjetaInfo(
              etiqueta: 'Factura del proveedor',
              valor: compra.numeroFactura ?? 'Sin factura',
            ),
            TarjetaInfo(
              etiqueta: 'Productos',
              valor: '${detalle.items.length}',
            ),
            TarjetaInfo(
              etiqueta: 'Costó',
              valor: formatearPrecio(compra.total),
            ),
          ],
        ),
        if (compra.notas != null) ...[
          const SizedBox(height: 14),
          Text(
            compra.notas!,
            style: TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
          ),
        ],
        const SizedBox(height: 18),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: detalle.items.length,
            itemBuilder: (context, i) => _Linea(item: detalle.items[i]),
          ),
        ),
        const Divider(height: 24, color: ColoresApp.borderFila),
        Row(
          children: [
            if (compra.anulada)
              Expanded(
                child: Text(
                  'Anulada: esta mercancía volvió a salir del inventario.',
                  style: TipografiaApp.caption
                      .copyWith(color: ColoresApp.statusDanger),
                ),
              )
            else
              const Spacer(),
            BotonSecundario(
              etiqueta: 'Imprimir',
              icono: Icons.print_outlined,
              alPresionar: () => unawaited(_imprimir(context, ref)),
            ),
            const SizedBox(width: 10),
            BotonSecundario(
              etiqueta: 'Cerrar',
              alPresionar: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }
}

/// Una línea de la remisión, ya congelada: nombre del día, cantidad y costo.
class _Linea extends StatelessWidget {
  const _Linea({required this.item});

  final CompraItem item;

  @override
  Widget build(BuildContext context) {
    return FilaDocumento(
      principal: MiniaturaLinea(
        rutaImagen: item.imagenUrl,
        iconoAlterno: Icons.inventory_2_outlined,
      ),
      titulo: item.descripcion,
      subtitulo: '${item.sku ?? ''} · '
          '${formatearCantidad(item.cantidad)} × '
          '${formatearPrecio(item.costoUnitario)}',
      precio: Text(
        formatearPrecio(item.subtotal),
        style: CampoPrecioLinea.estilo,
      ),
    );
  }
}
