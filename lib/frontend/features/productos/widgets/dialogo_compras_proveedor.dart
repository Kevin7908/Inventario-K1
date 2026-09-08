import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/compras/modelo/compra_item.dart';
import '../../../../backend/features/productos/modelo/proveedor_de_producto.dart';
import '../../../../core/formato.dart';
import '../../../share/share.dart';
import '../../compras/provider/compras_providers.dart';
import '../../compras/widgets/dialogo_detalle_compra.dart';

/// Todas las veces que este proveedor trajo este repuesto.
///
/// Es lo que la ficha no podía responder: enseñaba **la última** compra y con
/// eso se sabe el precio de hoy, pero no si subió. Aquí está la serie, que es
/// lo que se mira antes de volver a pedir.
///
/// Es un diálogo y no una pantalla porque se abre desde la lista de
/// proveedores de la ficha y se cierra volviendo a ella: la remisión completa
/// —con todo lo que traía y su anulación— vive en el módulo de Compras.
///
/// Parámetros:
/// - [productoId]: qué repuesto.
/// - [proveedor]: a quién se le compra, ya resuelto con su nombre y su
///   referencia.
///
/// Ejemplo:
/// ```dart
/// await DialogoComprasProveedor.mostrar(
///   context,
///   productoId: producto.id!,
///   proveedor: proveedor,
/// );
/// ```
class DialogoComprasProveedor extends ConsumerWidget {
  const DialogoComprasProveedor({
    super.key,
    required this.productoId,
    required this.proveedor,
  });

  final int productoId;
  final ProveedorDeProducto proveedor;

  static Future<void> mostrar(
    BuildContext context, {
    required int productoId,
    required ProveedorDeProducto proveedor,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => DialogoComprasProveedor(
        productoId: productoId,
        proveedor: proveedor,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compras = ref.watch(comprasDeProductoProvider((
      productoId: productoId,
      proveedorId: proveedor.proveedorId,
    )));

    return AtajosFormulario(
      alCancelar: () => Navigator.of(context).pop(),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ColoresApp.bgCard,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: ColoresApp.shadowMedium,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Titulo(proveedor: proveedor),
              const SizedBox(height: 18),
              Flexible(
                child: switch (compras) {
                  AsyncData(value: final lista) when lista.isEmpty =>
                    const _Hueco(),
                  AsyncData(value: final lista) => _Lista(compras: lista),
                  AsyncError() => const _Hueco(
                      texto: 'No se pudieron leer las remisiones',
                    ),
                  _ => const PanelSinDatos.cargando(),
                },
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: BotonSecundario(
                  etiqueta: 'Cerrar',
                  alPresionar: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo({required this.proveedor});

  final ProveedorDeProducto proveedor;

  @override
  Widget build(BuildContext context) {
    final referencia = (proveedor.referenciaProveedor ?? '').trim();

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: ColoresApp.statusInfoBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.local_shipping_outlined,
            color: ColoresApp.statusInfo,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(proveedor.proveedorNombre, style: TipografiaApp.heading3),
              const SizedBox(height: 2),
              Text(
                referencia.isEmpty
                    ? 'Lo que ha traído de este repuesto'
                    : 'Su referencia: $referencia',
                style: TipografiaApp.caption,
              ),
            ],
          ),
        ),
        if (proveedor.esPrincipal)
          const IndicadorEstado(
            etiqueta: 'Principal',
            color: ColoresApp.castletonGreen,
            colorFondo: ColoresApp.greenChipBg,
          ),
      ],
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.compras});

  final List<UltimaCompra> compras;

  @override
  Widget build(BuildContext context) {
    // Un repuesto que se compra todos los meses acumula remisiones sin techo,
    // así que va con `builder` y no con una columna concreta.
    return ListView.builder(
      shrinkWrap: true,
      itemCount: compras.length,
      itemBuilder: (context, i) => _Fila(
        compra: compras[i],
        // La primera es la vigente: es contra la que se compara el resto.
        vigente: i == 0,
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.compra, required this.vigente});

  final UltimaCompra compra;
  final bool vigente;

  @override
  Widget build(BuildContext context) {
    // La fila abre la remisión completa: desde aquí se ve el costo de esta
    // pieza, y a veces lo que hace falta es ver qué más venía en esa caja.
    return InkWell(
      onTap: () =>
          DialogoDetalleCompra.mostrar(context, compraId: compra.compraId),
      borderRadius: BorderRadius.circular(10),
      child: FilaMovimiento(
        icono: Icons.receipt_long_outlined,
        titulo: compra.numero,
        detalle: '${formatearFecha(compra.fecha)} · '
            '${formatearCantidad(compra.cantidad)} und',
        importe: formatearPrecio(compra.costoUnitario),
        color: vigente ? ColoresApp.castletonGreen : ColoresApp.textMuted,
      ),
    );
  }
}

class _Hueco extends StatelessWidget {
  const _Hueco({this.texto = 'Todavía no ha traído este repuesto con papel'});

  final String texto;

  @override
  Widget build(BuildContext context) => PanelSinDatos(
        icono: Icons.receipt_long_outlined,
        texto: texto,
      );
}
