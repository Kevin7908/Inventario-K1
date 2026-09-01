import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/deudores/enum/enum_deudor.dart';
import '../../../../../backend/features/deudores/modelo/deudor_item.dart';
import '../../../../../core/formato.dart';
import '../../../../../core/resultado.dart';
import '../../../../share/share.dart';
import '../../widgets/estado_deuda_ui.dart';
import '../provider/catalogo_deuda_providers.dart';
import '../provider/deuda_editor_provider.dart';
import 'dialogo_datos_deuda.dart';
import 'linea_deuda.dart';
import 'pie_deuda.dart';

/// Panel derecho de la ficha: lo que se llevó fiado y el estado de cuentas.
///
/// Mismo aside de 360 px que el punto de venta, las cotizaciones, las órdenes
/// y las reservas ([PanelDocumento]). Lo propio de una deuda es el pie: no
/// lleva subtotal ni IVA sino lo cobrado y lo que falta, porque la pregunta
/// aquí es cuánta plata está en la calle.
class PanelDeuda extends StatelessWidget {
  const PanelDeuda({super.key, required this.deudaId});

  static const double ancho = PanelDocumento.ancho;

  final int deudaId;

  @override
  Widget build(BuildContext context) {
    return PanelDocumento(
      cabecera: _Cabecera(deudaId: deudaId),
      contenido: _Lineas(deudaId: deudaId),
      pie: _Pie(deudaId: deudaId),
    );
  }
}

/// Título, contador, situación y a quién se le fió.
class _Cabecera extends ConsumerWidget {
  const _Cabecera({required this.deudaId});

  final int deudaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(
      deudaEditorProvider(deudaId).select((s) => (
            numero: s.value?.numero ?? '',
            cliente: s.value?.clienteNombre ?? '',
            moto: s.value?.motoDescripcion,
            concepto: s.value?.concepto,
            numeroOrden: s.value?.numeroOrden,
            vence: s.value?.fechaVencimiento,
            vencida: s.value?.estaVencida ?? false,
            estado: s.value?.estado,
            items: s.value?.lineas.length ?? 0,
          )),
    );

    final subtitulo = [
      ?datos.moto,
      // De dónde salió, cuando salió de una orden: es lo que lleva al sitio
      // donde sí se pueden corregir las líneas.
      if (datos.numeroOrden != null) 'de la orden ${datos.numeroOrden}',
      if (datos.numeroOrden == null) ?datos.concepto,
      if (datos.vence != null)
        datos.vencida
            ? 'venció el ${formatearFecha(datos.vence!)}'
            : 'vence el ${formatearFecha(datos.vence!)}',
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
                child: Text('Lo fiado', style: TipografiaApp.heading3),
              ),
              IndicadorEstado(
                etiqueta:
                    datos.items == 1 ? '1 ítem' : '${datos.items} ítems',
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
              if (datos.estado != null)
                _BadgeDeEstado(
                  estado: datos.estado!,
                  vencida: datos.vencida,
                ),
            ],
          ),
          const SizedBox(height: 12),
          FichaResumen(
            titulo: datos.cliente.isEmpty ? 'Sin cliente' : datos.cliente,
            subtitulo: subtitulo.isEmpty ? 'Sin moto ni plazo' : subtitulo,
            inicial: datos.cliente.isEmpty ? null : inicialDe(datos.cliente),
            icono: datos.cliente.isEmpty ? Icons.person_outline : null,
            etiquetaAccion: 'Moto, concepto, plazo y notas',
            alPresionar: () =>
                DialogoDatosDeuda.mostrar(context, deudaId: deudaId),
          ),
        ],
      ),
    );
  }
}

/// El badge de la cabecera, con la misma lectura que la fila del listado.
///
/// No usa `BadgeSituacionDeuda` porque ese recibe un `DeudorResumen` y aquí lo
/// que hay es el estado del editor; la traducción es la misma, y por eso
/// [SituacionDeuda] vive en un solo sitio.
class _BadgeDeEstado extends StatelessWidget {
  const _BadgeDeEstado({required this.estado, required this.vencida});

  final EstadoDeudor estado;
  final bool vencida;

  @override
  Widget build(BuildContext context) {
    final situacion = switch (estado) {
      EstadoDeudor.pagada => SituacionDeuda.pagada,
      EstadoDeudor.incobrable => SituacionDeuda.incobrable,
      _ => vencida ? SituacionDeuda.vencida : SituacionDeuda.alDia,
    };
    final estilo = estiloDeSituacion(situacion);

    return IndicadorEstado(
      etiqueta: estilo.etiqueta,
      color: estilo.color,
      colorFondo: estilo.fondo,
    );
  }
}

/// Los repuestos fiados. Es lo único del panel que cambia al anotar o quitar
/// algo, así que va en su propio widget.
class _Lineas extends ConsumerWidget {
  const _Lineas({required this.deudaId});

  final int deudaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = deudaEditorProvider(deudaId);
    final lineas = ref.watch(
      provider.select((s) => s.value?.lineas ?? const <DeudorItem>[]),
    );
    final editable =
        ref.watch(provider.select((s) => s.value?.editable ?? false));

    if (lineas.isEmpty) {
      return const EstadoVacio(
        icono: Icons.receipt_long_outlined,
        titulo: 'Todavía no se ha fiado nada',
        pista: 'Toca un repuesto de la izquierda para anotarlo en la deuda.',
      );
    }

    final notifier = ref.read(provider.notifier);
    final stock = ref.watch(stockPorProductoDeudaProvider);

    /// Lo que queda en bodega **más** lo que la línea ya se llevó: subir a esa
    /// cifra no le pide nada nuevo al inventario.
    double? topeDe(DeudorItem linea) {
      final disponible = stock[linea.productoId];
      return disponible == null ? null : disponible + linea.cantidad;
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      itemCount: lineas.length,
      itemBuilder: (context, i) {
        final linea = lineas[i];
        return LineaDeuda(
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

/// El estado de cuentas y las acciones que cierran o reabren la deuda.
class _Pie extends ConsumerWidget {
  const _Pie({required this.deudaId});

  final int deudaId;

  /// Dar una deuda por perdida **no devuelve nada al inventario**, y es la
  /// diferencia de fondo con cancelar una reserva: lo apartado sigue en la
  /// bodega, lo fiado se fue montado en una moto. El aviso lo dice con el
  /// número, porque es plata que el taller da por perdida.
  Future<void> _darPorPerdida(
    BuildContext context,
    WidgetRef ref,
    int saldo,
  ) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Dar la deuda por perdida?',
      mensaje: 'Se dejan de contar ${formatearPrecio(saldo)} en el total por '
          'cobrar. **Los repuestos no vuelven al inventario**: salieron del '
          'taller. La deuda y sus abonos siguen ahí, y se puede volver a '
          'cobrar después.',
    );
    if (confirmado != true) return;
    await ref
        .read(deudaEditorProvider(deudaId).notifier)
        .cambiarEstado(EstadoDeudor.incobrable);
  }

  Future<void> _reabrir(BuildContext context, WidgetRef ref) async {
    final resultado = await ref
        .read(deudaEditorProvider(deudaId).notifier)
        .cambiarEstado(EstadoDeudor.activa);
    if (!context.mounted) return;
    if (resultado case Fallo(:final mensaje)) MensajeApp.error(context, mensaje);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(
      deudaEditorProvider(deudaId).select((s) => (
            total: s.value?.montoTotal ?? 0,
            pagado: s.value?.montoPagado ?? 0,
            saldo: s.value?.saldo ?? 0,
            lineas: s.value?.lineas.length ?? 0,
            viva: s.value?.viva ?? false,
            estado: s.value?.estado,
            vencida: s.value?.estaVencida ?? false,
          )),
    );

    // Sin nada fiado no hay deuda que dar por perdida: cerrar una vacía solo
    // la saca del listado sin haber hecho nada.
    //
    // Mira `viva` y no `editable`: la que copia una orden no admite líneas
    // nuevas y aun así se puede dar por perdida, que es un cambio de estado.
    final puedeCerrar = datos.viva && datos.lineas > 0;

    final situacion = switch (datos.estado) {
      EstadoDeudor.pagada => SituacionDeuda.pagada,
      EstadoDeudor.incobrable => SituacionDeuda.incobrable,
      _ => datos.vencida ? SituacionDeuda.vencida : SituacionDeuda.alDia,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      decoration: const BoxDecoration(
        color: ColoresApp.bgCardHover,
        border: Border(top: BorderSide(color: ColoresApp.borderFila)),
      ),
      child: PieDeuda(
        total: datos.total,
        pagado: datos.pagado,
        colorAvance: colorDeAvance(situacion),
        alDarPorPerdida: puedeCerrar
            ? () => unawaited(_darPorPerdida(context, ref, datos.saldo))
            : null,
        // Solo la que se dio por perdida se puede reabrir: una pagada no se
        // «reabre», se le anota otro repuesto o se le borra el abono.
        alReabrir: datos.estado == EstadoDeudor.incobrable
            ? () => unawaited(_reabrir(context, ref))
            : null,
      ),
    );
  }
}
