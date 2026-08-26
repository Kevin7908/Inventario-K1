import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/pos/enum/enum_ventas.dart';
import '../../../../backend/features/pos/modelo/venta_resumen.dart';
import '../../../../core/formato.dart';
import '../../../share2/share2.dart';
import '../provider/historial_ventas_providers.dart';

/// Color de cada estado de pago, en un solo sitio.
///
/// Conoce `EstadoPago`, que es dominio, así que no cabe en share2.
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
          constructor: (v) => Text(
            formatearPrecio(v.total),
            textAlign: TextAlign.right,
            style: TipografiaApp.cuerpoMedium.copyWith(
              // Una anulada ya no vale lo que dice: se tacha en vez de
              // borrarla, porque el documento sigue existiendo.
              decoration: v.estadoPago == EstadoPago.anulada
                  ? TextDecoration.lineThrough
                  : null,
              color: v.estadoPago == EstadoPago.anulada
                  ? ColoresApp.textMuted
                  : ColoresApp.textPrimary,
            ),
          ),
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
