import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/compras/modelo/compra_item.dart';
import '../../../../backend/features/compras/modelo/compra_resumen.dart';
import '../../../../backend/share/dominio/permiso.dart';
import '../../../../core/formato.dart';
import '../../../../core/resultado.dart';
import '../../../share/share.dart';
import '../../autenticacion/widgets/si_puede.dart';
import '../../productos/widgets/miniatura_linea.dart';
import '../provider/compras_providers.dart';

/// La remisión abierta: qué llegó, a cuánto y de quién.
///
/// **Solo se lee y se anula.** Una compra registrada no se edita, por lo mismo
/// que una factura: explica entradas de inventario que ya ocurrieron. Anular
/// saca del stock lo que había entrado, y la base lo refuerza con sus guardas.
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

  Future<void> _anular(
    BuildContext context,
    WidgetRef ref,
    CompraResumen compra,
  ) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: 'Anular la compra ${compra.numero}',
      mensaje: 'Sale del inventario lo que había entrado con esta remisión. '
          'La compra no se borra: queda anulada, con su número.',
      textoConfirmar: 'Anular',
    );
    if (confirmado != true || !context.mounted) return;

    final resultado = await ref.read(repositorioComprasProvider).anular(
          compra.id,
        );
    if (!context.mounted) return;

    switch (resultado) {
      case Exito():
        ref.invalidate(compraDetalleProvider(compra.id));
        Navigator.of(context).pop();
        MensajeApp.exito(context, 'Compra ${compra.numero} anulada');
      case Fallo(:final mensaje):
        MensajeApp.error(context, mensaje);
    }
  }

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
            data: (compra) => _Contenido(
              detalle: compra,
              alAnular: () => _anular(context, ref, compra.resumen),
            ),
          ),
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.detalle, required this.alAnular});

  final CompraDetalle detalle;
  final VoidCallback alAnular;

  @override
  Widget build(BuildContext context) {
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
            IndicadorEstado(
              etiqueta: compra.estado.etiqueta,
              color: compra.anulada
                  ? ColoresApp.statusDanger
                  : ColoresApp.statusSuccess,
              colorFondo: compra.anulada
                  ? ColoresApp.statusDangerBg
                  : ColoresApp.statusSuccessBg,
            ),
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
            if (!compra.anulada)
              SiPuede(
                permiso: Permiso.comprasAnular,
                child: BotonDestructivo(
                  etiqueta: 'Anular compra',
                  alPresionar: alAnular,
                ),
              ),
            const SizedBox(width: 12),
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
