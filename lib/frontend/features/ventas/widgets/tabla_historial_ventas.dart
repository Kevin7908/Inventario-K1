import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/pos/enum/enum_ventas.dart';
import '../../../../backend/features/pos/modelo/venta_resumen.dart';
import '../../../../core/formato.dart';
import '../../../../backend/share/dominio/permiso.dart';
import '../../../../backend/share/dominio/sesion_actual.dart';
import '../../../share/share.dart';
import '../../autenticacion/widgets/si_puede.dart';
import '../../documentos/provider/documentos_providers.dart';
import '../../documentos/traductores/venta_a_documento.dart';
import '../../documentos/widgets/dialogo_vista_previa.dart';
import '../../pos/provider/pos_providers.dart';
import '../provider/historial_ventas_providers.dart';
import 'dialogo_devolucion.dart';

/// Color de cada estado de pago, en un solo sitio.
///
/// Conoce `EstadoPago`, que es dominio, así que no cabe en share.
({Color color, Color fondo}) colorDeEstadoPago(EstadoPago estado) =>
    switch (estado) {
      EstadoPago.pagado => (
          color: ColoresApp.statusSuccess,
          fondo: ColoresApp.statusSuccessBg,
        ),
      EstadoPago.pendiente => (
          color: ColoresApp.statusWarning,
          fondo: ColoresApp.statusWarningBg,
        ),
      EstadoPago.anulada => (
          color: ColoresApp.statusDanger,
          fondo: ColoresApp.statusDangerBg,
        ),
    };

/// La tabla del historial: cuándo, qué factura, a quién, quién la hizo y
/// cuánto.
///
/// Observa `ventasPaginaProvider` ella sola para que escribir en el buscador
/// no reconstruya el encabezado ni los filtros (`CLAUDE.md` §3).
class TablaHistorialVentas extends ConsumerWidget {
  const TablaHistorialVentas({super.key, required this.alLimpiarFiltros});

  final VoidCallback alLimpiarFiltros;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ventas = ref.watch(ventasPaginaProvider);
    final hayFiltro =
        ref.watch(historialVentasProvider).value?.hayFiltro ?? false;

    if (ventas.isEmpty) {
      return _Vacio(hayFiltro: hayFiltro, alLimpiarFiltros: alLimpiarFiltros);
    }

    return TablaGenerica<VentaResumen>(
      items: ventas,
      columnas: [
        ColumnaTabla<VentaResumen>(
          titulo: 'Cuándo',
          flex: 2,
          constructor: (v) => _Cuando(fecha: v.creadoEn),
        ),
        ColumnaTabla<VentaResumen>(
          titulo: 'Factura',
          flex: 2,
          constructor: (v) => _Factura(venta: v),
        ),
        ColumnaTabla<VentaResumen>(
          titulo: 'Cliente',
          flex: 3,
          constructor: (v) => Text(
            v.clienteNombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TipografiaApp.cuerpo,
          ),
        ),
        ColumnaTabla<VentaResumen>(
          titulo: 'Quién la hizo',
          flex: 3,
          constructor: (v) => _Cajero(nombre: v.cajero),
        ),
        ColumnaTabla<VentaResumen>(
          titulo: 'Estado',
          flex: 2,
          constructor: (v) => _Estado(estado: v.estadoPago),
        ),
        ColumnaTabla<VentaResumen>(
          titulo: 'Total',
          flex: 2,
          alineacion: Alignment.centerRight,
          constructor: (v) => _Total(venta: v),
        ),
        ColumnaTabla<VentaResumen>(
          titulo: '',
          ancho: 92,
          alineacion: Alignment.centerRight,
          constructor: (v) => _Acciones(venta: v),
        ),
      ],
    );
  }
}

class _Cuando extends StatelessWidget {
  const _Cuando({required this.fecha});

  final DateTime? fecha;

  @override
  Widget build(BuildContext context) {
    final valor = fecha;
    if (valor == null) {
      return Text(
        '—',
        style: TipografiaApp.caption.copyWith(color: ColoresApp.textDisabled),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(formatearFecha(valor), style: TipografiaApp.cuerpoMedium),
        Text(
          formatearHora(valor),
          style: TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
        ),
      ],
    );
  }
}

/// El número y de dónde salió: mostrador, o la orden que se facturó.
class _Factura extends StatelessWidget {
  const _Factura({required this.venta});

  final VentaResumen venta;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          venta.numeroFactura,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TipografiaApp.monoespaciada(TipografiaApp.cuerpoMedium),
        ),
        Text(
          venta.numeroOrden ?? venta.tipo.etiqueta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
        ),
      ],
    );
  }
}

/// Lo cobrado, y debajo lo que ya volvió si hubo devoluciones.
///
/// **El total no se recalcula**: la factura dice lo que se cobró. Lo devuelto
/// va en su propio renglón para que quien cuadra la caja vea las dos cifras.
class _Total extends StatelessWidget {
  const _Total({required this.venta});

  final VentaResumen venta;

  @override
  Widget build(BuildContext context) {
    final anulada = venta.estadoPago == EstadoPago.anulada;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatearPrecio(venta.total),
          textAlign: TextAlign.right,
          style: TipografiaApp.cuerpoMedium.copyWith(
            // Una anulada ya no vale lo que dice: se tacha en vez de
            // borrarla, porque el documento sigue existiendo.
            decoration: anulada ? TextDecoration.lineThrough : null,
            color: anulada ? ColoresApp.textMuted : ColoresApp.textPrimary,
          ),
        ),
        if (venta.tieneDevoluciones && !anulada)
          Text(
            '−${formatearPrecio(venta.totalDevuelto)} devuelto',
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TipografiaApp.caption
                .copyWith(color: ColoresApp.statusDanger),
          ),
      ],
    );
  }
}

/// Devolver una parte, o anular la venta entera.
///
/// Las dos compuertas son `POS_ANULAR`: devolver es estrictamente menos que
/// anular. Esconder los botones es orden; el control está en el repositorio
/// (`CLAUDE.md` §7 bis).
class _Acciones extends ConsumerWidget {
  const _Acciones({required this.venta});

  final VentaResumen venta;

  Future<void> _anular(BuildContext context, WidgetRef ref) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Anular ${venta.numeroFactura}?',
      mensaje: 'La factura queda anulada con su número —no se borra— y toda '
          'la mercancía que quede sin devolver vuelve al inventario. No tiene '
          'vuelta atrás.',
      textoConfirmar: 'Anular',
    );
    if (confirmado != true || !context.mounted) return;

    try {
      await ref.read(repositorioVentasProvider).anular(venta.id);
      if (!context.mounted) return;
      MensajeApp.exito(context, '${venta.numeroFactura} quedó anulada.');
    } on PermisoDenegado catch (e) {
      if (!context.mounted) return;
      MensajeApp.error(context, e.mensaje);
    } on Exception catch (e) {
      if (!context.mounted) return;
      MensajeApp.error(context, 'No se pudo anular: $e');
    }
  }

  /// Vuelve a abrir la factura ya emitida.
  ///
  /// El cliente que pierde el papel vuelve al mostrador, y hasta ahora la
  /// única forma de imprimir era al cobrar. Sale de lo guardado, así que una
  /// factura anulada se reimprime diciendo que está anulada.
  Future<void> _imprimir(BuildContext context, WidgetRef ref) async {
    try {
      final detalle =
          await ref.read(repositorioVentasProvider).obtenerDetalle(venta.id);
      final negocio =
          await leerNegocioImpreso(ref.read(repositorioConfiguracionProvider));
      if (!context.mounted) return;

      await DialogoVistaPrevia.mostrar(
        context,
        documento: documentoDeVenta(venta: detalle, negocio: negocio),
      );
    } catch (e) {
      if (!context.mounted) return;
      MensajeApp.error(context, 'No se pudo abrir la factura: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reimprimir no está detrás de `POS_ANULAR` ni se esconde en una factura
    // anulada: dar una copia del papel no cambia nada, y el documento anulado
    // es justo el que a veces hay que enseñar.
    final imprimir = BotonIcono(
      icono: Icons.print_outlined,
      tooltip: 'Imprimir la factura',
      alPresionar: () => _imprimir(context, ref),
    );

    // Una factura anulada está cerrada: ni se devuelve ni se vuelve a anular.
    if (venta.estadoPago == EstadoPago.anulada) {
      return imprimir;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        imprimir,
        SiPuede(
          permiso: Permiso.posAnular,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BotonIcono(
                icono: Icons.keyboard_return_rounded,
                tooltip: 'Recibir una devolución',
                alPresionar: () =>
                    DialogoDevolucion.mostrar(context, venta: venta),
              ),
              BotonIcono(
                icono: Icons.block_outlined,
                tooltip: 'Anular la venta entera',
                color: ColoresApp.statusDanger,
                alPresionar: () => _anular(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Cajero extends StatelessWidget {
  const _Cajero({required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AvatarUsuario(iniciales: inicialDe(nombre), tamano: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TipografiaApp.cuerpo,
          ),
        ),
      ],
    );
  }
}

class _Estado extends StatelessWidget {
  const _Estado({required this.estado});

  final EstadoPago estado;

  @override
  Widget build(BuildContext context) {
    final estilo = colorDeEstadoPago(estado);

    return Row(
      children: [
        Flexible(
          child: IndicadorEstado(
            etiqueta: estado.etiqueta,
            color: estilo.color,
            colorFondo: estilo.fondo,
            conPunto: true,
          ),
        ),
      ],
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.hayFiltro, required this.alLimpiarFiltros});

  final bool hayFiltro;
  final VoidCallback alLimpiarFiltros;

  @override
  Widget build(BuildContext context) {
    if (!hayFiltro) {
      return const EstadoVacio(
        icono: Icons.receipt_long_outlined,
        titulo: 'Todavía no se ha vendido nada',
        pista: 'Las ventas del mostrador aparecen aquí en cuanto se cobra la '
            'primera.',
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const EstadoVacio(
          icono: Icons.filter_alt_off_outlined,
          titulo: 'Ninguna venta con esos filtros',
          pista: 'Prueba con otro rango de fechas o quita el estado.',
        ),
        BotonSecundario(
          etiqueta: 'Quitar los filtros',
          icono: Icons.close_rounded,
          alPresionar: alLimpiarFiltros,
        ),
      ],
    );
  }
}
