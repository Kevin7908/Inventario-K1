import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/productos/modelo/producto.dart';
import '../../../../../backend/features/reservas/enum/enum_reserva.dart';
import '../../../../../backend/features/reservas/modelo/reserva_item.dart';
import '../../../../../core/formato.dart';
import '../../../../share/share.dart';
import '../../../documentos/provider/documentos_providers.dart';
import '../../../documentos/traductores/reserva_a_documento.dart';
import '../../../documentos/widgets/dialogo_vista_previa.dart';
import '../../../productos/provider/productos_provider.dart';
import '../../provider/reservas_providers.dart';
import '../../widgets/estado_reserva_ui.dart';
import '../provider/reserva_editor_provider.dart';
import 'dialogo_datos_reserva.dart';
import 'linea_reserva.dart';
import 'pie_reserva.dart';

/// Panel derecho del editor: la mercancía apartada y el estado de cuentas.
///
/// Mismo aside de 360 px que el punto de venta, las cotizaciones y las
/// órdenes ([PanelDocumento]). Lo propio de una reserva es el pie: no lleva
/// subtotal ni IVA sino deuda, porque lo que se pregunta aquí es cuánto falta
/// por cobrar.
class PanelReserva extends StatelessWidget {
  const PanelReserva({super.key, required this.reservaId});

  static const double ancho = PanelDocumento.ancho;

  final int reservaId;

  @override
  Widget build(BuildContext context) {
    return PanelDocumento(
      cabecera: _Cabecera(reservaId: reservaId),
      contenido: _Lineas(reservaId: reservaId),
      pie: _Pie(reservaId: reservaId),
    );
  }
}

/// Título, contador, estado y a quién se le aparta.
class _Cabecera extends ConsumerWidget {
  const _Cabecera({required this.reservaId});

  final int reservaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(
      reservaEditorProvider(reservaId).select((s) => (
            numero: s.value?.numero ?? '',
            cliente: s.value?.clienteNombre ?? '',
            moto: s.value?.motoDescripcion,
            placa: s.value?.motoPlaca,
            limite: s.value?.fechaLimite,
            estado: s.value?.estado,
            items: s.value?.lineas.length ?? 0,
            pagada: s.value?.pagada ?? false,
          )),
    );

    final estado = datos.estado;
    final subtitulo = [
      if (datos.moto != null) datos.moto!,
      if (datos.placa != null) datos.placa!,
      if (datos.limite != null) 'hasta ${formatearFecha(datos.limite!)}',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ColoresApp.borderFila)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Reserva actual', style: TipografiaApp.heading3),
              ),
              IndicadorEstado(
                etiqueta: datos.items == 1 ? '1 ítem' : '${datos.items} ítems',
                color: ColoresApp.castletonGreen,
                colorFondo: ColoresApp.statusSuccessBg,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${datos.numero}',
                  style: TipografiaApp.caption.copyWith(
                    fontSize: 12,
                    color: ColoresApp.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (estado != null && estado != EstadoReserva.activa)
                BadgeEstadoReserva(estado: estado)
              else
                IndicadorEstado(
                  etiqueta: datos.pagada ? 'Pagada' : 'Abonando',
                  color: coloresDeSaldo(pagada: datos.pagada).color,
                  colorFondo: coloresDeSaldo(pagada: datos.pagada).fondo,
                ),
            ],
          ),
          const SizedBox(height: 12),
          FichaResumen(
            titulo: datos.cliente.isEmpty ? 'Sin cliente' : datos.cliente,
            subtitulo: subtitulo.isEmpty ? 'Sin moto ni plazo' : subtitulo,
            inicial:
                datos.cliente.isEmpty ? null : inicialDe(datos.cliente),
            icono: datos.cliente.isEmpty ? Icons.person_outline : null,
            etiquetaAccion: 'Moto, plazo y estado de la reserva',
            alPresionar: () =>
                DialogoDatosReserva.mostrar(context, reservaId: reservaId),
          ),
        ],
      ),
    );
  }
}

/// La mercancía apartada. Es lo único del panel que cambia al agregar o quitar
/// algo, así que va en su propio widget.
class _Lineas extends ConsumerWidget {
  const _Lineas({required this.reservaId});

  final int reservaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = reservaEditorProvider(reservaId);
    final lineas = ref.watch(
      provider.select((s) => s.value?.lineas ?? const <ReservaItem>[]),
    );
    final editable =
        ref.watch(provider.select((s) => s.value?.editable ?? false));

    if (lineas.isEmpty) {
      return const EstadoVacio(
        icono: Icons.bookmark_border_rounded,
        titulo: 'No hay nada apartado',
        pista: 'Toca un producto de la izquierda para reservarlo.',
      );
    }

    final notifier = ref.read(provider.notifier);
    final stock = ref.watch(stockPorProductoProvider);

    /// Lo que queda en bodega **más** lo que la línea ya apartó: subir a esa
    /// cifra no le pide nada nuevo al inventario.
    double? topeDe(ReservaItem linea) {
      final disponible = stock[linea.productoId];
      return disponible == null ? null : disponible + linea.cantidad;
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      itemCount: lineas.length,
      itemBuilder: (context, i) {
        final linea = lineas[i];
        return LineaReserva(
          key: ValueKey(linea.id),
          linea: linea,
          editable: editable,
          disponible: topeDe(linea),
          alCambiarCantidad: (cantidad) =>
              notifier.cambiarCantidad(linea, cantidad),
          alEliminar: () => unawaited(notifier.eliminarLinea(linea)),
        );
      },
    );
  }
}

/// Cuánto queda en bodega de cada producto, por id.
///
/// Sale del catálogo completo porque la línea guarda el id y necesita el tope
/// para no dejar pedir más de lo que hay.
final stockPorProductoProvider = Provider<Map<int, double>>(
  name: 'stockPorProductoProvider',
  (ref) {
    final todos =
        ref.watch(catalogoCompletoProvider).value ?? const <Producto>[];
    return {
      for (final p in todos)
        if (p.id != null) p.id!: p.stockActual,
    };
  },
);

/// El estado de cuentas y la acción de cancelar.
class _Pie extends ConsumerWidget {
  const _Pie({required this.reservaId});

  final int reservaId;

  /// Entregar cierra la reserva **sin devolver nada** al inventario: la
  /// mercancía salió de verdad. Si queda saldo, el aviso lo dice con el número
  /// —el taller decide si deja llevarla fiada, pero no debería enterarse
  /// después—.
  Future<void> _entregar(BuildContext context, WidgetRef ref, int saldo) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Marcar como entregada?',
      mensaje: saldo > 0
          ? 'El cliente se lleva la mercancía y la reserva se cierra. '
              'Quedan ${formatearPrecio(saldo)} sin pagar, y después no se le '
              'podrán agregar ni quitar productos.'
          : 'El cliente se lleva la mercancía y la reserva se cierra. No '
              'vuelve al inventario, porque salió de verdad. Después no se le '
              'podrán agregar ni quitar productos.',
    );
    if (confirmado != true) return;
    await ref
        .read(reservaEditorProvider(reservaId).notifier)
        .cambiarEstado(EstadoReserva.completada);
  }

  /// Abre el comprobante: lo que el cliente se lleva de una reserva, con sus
  /// abonos y su saldo.
  ///
  /// Relee el detalle en vez de armarlo con lo que tiene el editor a la vista
  /// porque el editor guarda el estado **de edición** —líneas y totales— y no
  /// los abonos; y porque el papel tiene que salir de lo que está guardado, no
  /// de lo que hay en pantalla.
  Future<void> _imprimir(BuildContext context, WidgetRef ref) async {
    try {
      final reserva = await ref.read(detalleReservaProvider(reservaId).future);
      final negocio =
          await leerNegocioImpreso(ref.read(repositorioConfiguracionProvider));
      if (!context.mounted) return;

      await DialogoVistaPrevia.mostrar(
        context,
        documento: documentoDeReserva(reserva: reserva, negocio: negocio),
      );
    } catch (e) {
      if (!context.mounted) return;
      MensajeApp.error(context, 'No se pudo abrir el comprobante: $e');
    }
  }

  Future<void> _cancelar(BuildContext context, WidgetRef ref) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Cancelar la reserva?',
      mensaje: 'Todo lo apartado vuelve al inventario. Si el cliente ya '
          'entregó dinero, hay que devolvérselo aparte: la reserva conserva '
          'su historial de abonos.',
    );
    if (confirmado != true) return;
    await ref
        .read(reservaEditorProvider(reservaId).notifier)
        .cambiarEstado(EstadoReserva.cancelada);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(
      reservaEditorProvider(reservaId).select((s) => (
            total: s.value?.totalReserva ?? 0,
            pagado: s.value?.pagadoAcumulado ?? 0,
            saldo: s.value?.saldo ?? 0,
            lineas: s.value?.lineas.length ?? 0,
            editable: s.value?.editable ?? false,
          )),
    );

    // Sin nada apartado no hay nada que entregar: cerrar una reserva vacía
    // solo la saca del listado sin haber hecho nada.
    final puedeEntregar = datos.editable && datos.lineas > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      decoration: const BoxDecoration(
        color: ColoresApp.bgInput,
        border: Border(top: BorderSide(color: ColoresApp.borderFila)),
      ),
      child: PieReserva(
        total: datos.total,
        pagado: datos.pagado,
        alEntregar: puedeEntregar
            ? () => unawaited(_entregar(context, ref, datos.saldo))
            : null,
        alCancelar:
            datos.editable ? () => unawaited(_cancelar(context, ref)) : null,
        alImprimir: () => unawaited(_imprimir(context, ref)),
      ),
    );
  }
}
