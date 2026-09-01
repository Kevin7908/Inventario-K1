import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/devoluciones/modelo/devolucion.dart';
import '../../../../backend/features/pos/enum/enum_ventas.dart';
import '../../../../backend/features/pos/modelo/venta_detalle.dart';
import '../../../../backend/features/pos/modelo/venta_item.dart';
import '../../../../core/formato.dart';
import '../../../../core/iva_app.dart';
import '../../../share/share.dart';
import '../provider/devoluciones_providers.dart';
import '../provider/historial_ventas_providers.dart';
import 'tabla_historial_ventas.dart';

/// Qué se vendió en una factura y qué volvió después.
///
/// El historial mostraba el resumen y las acciones, y nada más: para saber qué
/// líneas tenía una factura había que reimprimirla, y las devoluciones
/// registradas no se podían consultar en ninguna parte —solo se veía el total
/// devuelto bajo el importe—.
///
/// **Solo lee.** Devolver y anular siguen siendo los botones de la fila: aquí
/// no hay nada que guardar.
///
/// Las devoluciones van **debajo de las líneas y no mezcladas con ellas**: la
/// factura dice lo que se cobró y lo sigue diciendo; lo que volvió es otro
/// documento, con su número, su fecha y quién lo recibió.
///
/// Parámetros:
/// - [venta]: la factura que se abre.
///
/// Ejemplo:
/// ```dart
/// await DialogoDetalleVenta.mostrar(context, ventaId: venta.id);
/// ```
class DialogoDetalleVenta extends ConsumerWidget {
  const DialogoDetalleVenta({super.key, required this.ventaId});

  final int ventaId;

  static Future<void> mostrar(BuildContext context, {required int ventaId}) =>
      showDialog<void>(
        context: context,
        builder: (_) => DialogoDetalleVenta(ventaId: ventaId),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalle = ref.watch(ventaDetalleProvider(ventaId));

    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 660),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (detalle) {
            AsyncData(value: final venta) => _Contenido(venta: venta),
            AsyncError(:final error) => AvisoEnLinea(
                mensaje: 'No se pudo abrir la factura: $error',
                tono: TonoAviso.error,
              ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.venta});

  final VentaDetalle venta;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Cabecera(venta: venta),
        const SizedBox(height: 18),
        FilaCampos(
          hijos: [
            TarjetaInfo(
              etiqueta: 'Cliente',
              valor: venta.clienteNombre,
            ),
            TarjetaInfo(
              etiqueta: 'Cómo pagó',
              valor: venta.metodoPago.etiqueta,
            ),
            TarjetaInfo(
              etiqueta: 'Total',
              valor: formatearPrecio(venta.total),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final item in venta.items)
                _Linea(key: ValueKey(item.id), item: item),
              const SizedBox(height: 8),
              _Totales(venta: venta),
              const SizedBox(height: 8),
              _Devoluciones(ventaId: venta.id),
            ],
          ),
        ),
        const Divider(height: 24, color: ColoresApp.borderFila),
        Align(
          alignment: Alignment.centerRight,
          child: BotonSecundario(
            etiqueta: 'Cerrar',
            alPresionar: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.venta});

  final VentaDetalle venta;

  @override
  Widget build(BuildContext context) {
    final colores = colorDeEstadoPago(venta.estadoPago);
    final cuando = venta.creadoEn;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                venta.numeroFactura,
                style: TipografiaApp.monoespaciada(TipografiaApp.heading3),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  venta.numeroOrden ?? venta.tipo.etiqueta,
                  if (cuando != null) formatearFechaHora(cuando),
                ].join(' · '),
                style:
                    TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
              ),
            ],
          ),
        ),
        IndicadorEstado(
          etiqueta: venta.estadoPago.etiqueta,
          color: colores.color,
          colorFondo: colores.fondo,
        ),
      ],
    );
  }
}

/// Una línea tal como quedó congelada en la factura: el nombre del día, la
/// cantidad y el precio al que se cobró, no el del catálogo de hoy.
class _Linea extends StatelessWidget {
  const _Linea({super.key, required this.item});

  final VentaItem item;

  @override
  Widget build(BuildContext context) {
    final esServicio = item.tipoItem == TipoItem.servicio;

    return FilaDocumento(
      principal: Icon(
        esServicio ? Icons.build_outlined : Icons.inventory_2_outlined,
        size: 18,
        color: ColoresApp.textMuted,
      ),
      titulo: item.descripcion,
      subtitulo: '${formatearCantidad(item.cantidad)} × '
          '${formatearPrecio(item.precioUnitario)}',
      precio: Text(
        formatearPrecio(item.subtotal),
        style: CampoPrecioLinea.estilo,
      ),
    );
  }
}

/// El pie de la factura, de solo lectura.
///
/// No usa `PieTotales` de share porque aquél existe para **editar** el
/// descuento: pide controlador, foco y callback. Aquí no hay nada que teclear.
class _Totales extends StatelessWidget {
  const _Totales({required this.venta});

  final VentaDetalle venta;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RenglonCuenta(
          etiqueta: 'Subtotal',
          valor: formatearPrecio(venta.subtotal),
        ),
        if (venta.descuento > 0) ...[
          const SizedBox(height: 8),
          RenglonCuenta(
            etiqueta: 'Descuento',
            valor: '−${formatearPrecio(venta.descuento)}',
            color: ColoresApp.statusWarning,
          ),
        ],
        const SizedBox(height: 8),
        RenglonCuenta(
          etiqueta: 'Total cobrado',
          valor: formatearPrecio(venta.total),
        ),
        // El IVA va **debajo** del total y no encima, por lo mismo que en
        // `PieTotales`: los precios ya lo traen dentro, así que no suma.
        if (hayIva) ...[
          const SizedBox(height: 8),
          RenglonCuenta(
            etiqueta: etiquetaIva,
            valor: formatearPrecio(venta.iva),
          ),
        ],
      ],
    );
  }
}

/// Lo que volvió de esta factura, documento por documento.
class _Devoluciones extends ConsumerWidget {
  const _Devoluciones({required this.ventaId});

  final int ventaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devoluciones = ref.watch(devolucionesDeVentaProvider(ventaId));

    return switch (devoluciones) {
      // Sin devoluciones no se pinta nada: un bloque vacío diciendo «no hubo
      // devoluciones» solo alarga el diálogo de la factura corriente.
      AsyncData(value: final lista) when lista.isEmpty => const SizedBox.shrink(),
      AsyncData(value: final lista) => _ListaDevoluciones(devoluciones: lista),
      AsyncError(:final error) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AvisoEnLinea(
            mensaje: 'No se pudieron leer las devoluciones: $error',
            tono: TonoAviso.error,
          ),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _ListaDevoluciones extends StatelessWidget {
  const _ListaDevoluciones({required this.devoluciones});

  final List<Devolucion> devoluciones;

  @override
  Widget build(BuildContext context) {
    final total =
        devoluciones.fold<int>(0, (suma, d) => suma + d.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        EncabezadoGrupoLineas(
          icono: Icons.keyboard_return_rounded,
          titulo: 'Devuelto',
          subtotal: total,
        ),
        for (final devolucion in devoluciones)
          _Devolucion(key: ValueKey(devolucion.id), devolucion: devolucion),
      ],
    );
  }
}

/// Un documento de devolución: cuándo, por qué, quién lo recibió y si la
/// mercancía volvió al estante.
class _Devolucion extends StatelessWidget {
  const _Devolucion({super.key, required this.devolucion});

  final Devolucion devolucion;

  @override
  Widget build(BuildContext context) {
    // Las líneas de servicio no mueven inventario nunca, así que decir «no
    // volvió al inventario» de una devolución que solo tiene servicios sería
    // ruido: solo se avisa cuando había piezas que podían volver.
    final hayPiezas = devolucion.lineas.any((l) => l.productoId != null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${devolucion.numero} · ${devolucion.motivo.etiqueta}',
                  style: TipografiaApp.cuerpoMedium,
                ),
              ),
              Text(
                '−${formatearPrecio(devolucion.total)}',
                style: TipografiaApp.cuerpoMedium
                    .copyWith(color: ColoresApp.statusDanger),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${formatearFecha(devolucion.creadoEn)} · '
            'la recibió ${devolucion.recibidoPor}',
            style: TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
          ),
          for (final linea in devolucion.lineas)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Text(
                '${formatearCantidad(linea.cantidad)} × ${linea.descripcion}',
                style:
                    TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
              ),
            ),
          if (hayPiezas && !devolucion.reingresaStock) ...[
            const SizedBox(height: 6),
            Text(
              'No volvió al inventario: apartada para el proveedor.',
              style: TipografiaApp.caption
                  .copyWith(color: ColoresApp.statusWarning),
            ),
          ],
          if (devolucion.notas != null && devolucion.notas!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              devolucion.notas!,
              style:
                  TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
