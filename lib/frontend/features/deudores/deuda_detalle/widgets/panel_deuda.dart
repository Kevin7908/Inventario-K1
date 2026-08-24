import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/deudores/enum/enum_deudor.dart';
import '../../../../../core/formato.dart';
import '../../../../../core/resultado.dart';
import '../../../../share2/share2.dart';
import '../../widgets/estado_deuda_ui.dart';
import '../provider/deuda_editor_provider.dart';
import 'dialogo_datos_deuda.dart';
import 'pie_deuda.dart';

/// Panel derecho de la ficha: quién debe, por qué, y el estado de cuentas.
///
/// Mismo aside de 360 px que el punto de venta, las cotizaciones, las órdenes
/// y las reservas ([PanelDocumento]). Lo propio de una deuda es que **el medio
/// no lleva líneas**: no hay mercancía que listar, solo el concepto, el plazo
/// y lo que se anotó. Por eso el contenido es texto y no un `ListView`.
class PanelDeuda extends StatelessWidget {
  const PanelDeuda({super.key, required this.deudaId});

  static const double ancho = PanelDocumento.ancho;

  final int deudaId;

  @override
  Widget build(BuildContext context) {
    return PanelDocumento(
      cabecera: _Cabecera(deudaId: deudaId),
      contenido: _Cuerpo(deudaId: deudaId),
      pie: _Pie(deudaId: deudaId),
    );
  }
}

/// Título, número, situación y a quién se le fía.
class _Cabecera extends ConsumerWidget {
  const _Cabecera({required this.deudaId});

  final int deudaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deuda =
        ref.watch(deudaEditorProvider(deudaId).select((s) => s.value?.deuda));
    if (deuda == null) return const SizedBox.shrink();

    final vence = deuda.fechaVencimiento;
    final subtitulo = vence == null
        ? 'Sin plazo pactado'
        : deuda.estaVencida
            ? 'Venció el ${formatearFecha(vence)}'
            : 'Vence el ${formatearFecha(vence)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ColoresApp.borderFila)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Deuda', style: TipografiaApp.heading3),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${deuda.numero}',
                  style: TipografiaApp.caption.copyWith(
                    fontSize: 12,
                    color: ColoresApp.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              BadgeSituacionDeuda(deuda: deuda),
            ],
          ),
          const SizedBox(height: 12),
          FichaResumen(
            titulo: deuda.nombreCliente,
            subtitulo: subtitulo,
            inicial: inicialDe(deuda.nombreCliente),
            etiquetaAccion: 'Concepto, monto, plazo y notas',
            alPresionar: () =>
                DialogoDatosDeuda.mostrar(context, deudaId: deudaId),
          ),
        ],
      ),
    );
  }
}

/// Por qué se debe y lo que se acordó. Es lo único que hay entre la cabecera y
/// las cuentas, así que va con aire y no apretado como una línea de documento.
class _Cuerpo extends ConsumerWidget {
  const _Cuerpo({required this.deudaId});

  final int deudaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(
      deudaEditorProvider(deudaId).select((s) => (
            concepto: s.value?.deuda.concepto ?? '',
            notas: s.value?.deuda.notas,
            abierta: s.value?.deuda.creadoEn,
            pagos: s.value?.pagos.length ?? 0,
          )),
    );
    final notas = datos.notas;
    final abierta = datos.abierta;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
      children: [
        PanelSeccion(
          titulo: 'Concepto',
          icono: Icons.description_outlined,
          child: Text(
            datos.concepto.isEmpty ? 'Sin concepto' : datos.concepto,
            style: TipografiaApp.cuerpo.copyWith(fontSize: 13),
          ),
        ),
        const SizedBox(height: 14),
        PanelSeccion(
          titulo: 'La deuda',
          icono: Icons.event_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilaDato(
                icono: Icons.calendar_today_outlined,
                texto: abierta == null
                    ? 'Sin fecha de apertura'
                    : 'Abierta el ${formatearFecha(abierta)}',
              ),
              const SizedBox(height: 6),
              FilaDato(
                icono: Icons.receipt_long_outlined,
                texto: switch (datos.pagos) {
                  0 => 'Todavía no ha abonado nada',
                  1 => '1 abono recibido',
                  final n => '$n abonos recibidos',
                },
              ),
            ],
          ),
        ),
        if (notas != null && notas.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          PanelSeccion(
            titulo: 'Notas',
            icono: Icons.sticky_note_2_outlined,
            child: Text(
              notas,
              style: TipografiaApp.cuerpo.copyWith(
                fontSize: 12.5,
                color: ColoresApp.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// El estado de cuentas y las acciones que cierran o reabren la deuda.
class _Pie extends ConsumerWidget {
  const _Pie({required this.deudaId});

  final int deudaId;

  /// Dar una deuda por perdida **no cobra nada**: la saca de la cartera y
  /// reconoce que esa plata no vuelve. Por eso se confirma, y por eso el aviso
  /// dice el saldo con el número.
  Future<void> _darPorPerdida(
    BuildContext context,
    WidgetRef ref,
    int saldo,
  ) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Dar la deuda por perdida?',
      mensaje: 'Se dejan de contar ${formatearPrecio(saldo)} en el total por '
          'cobrar. **No se borra nada**: la deuda y sus abonos siguen ahí, '
          'y se puede volver a cobrar después.',
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
            editable: s.value?.editable ?? false,
            estado: s.value?.deuda.estado,
            situacion: s.value == null ? null : situacionDe(s.value!.deuda),
          )),
    );
    final situacion = datos.situacion;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      decoration: const BoxDecoration(
        color: ColoresApp.bgCardHover,
        border: Border(top: BorderSide(color: ColoresApp.borderFila)),
      ),
      child: PieDeuda(
        total: datos.total,
        pagado: datos.pagado,
        colorAvance: situacion == null
            ? ColoresApp.goGreen
            : colorDeAvance(situacion),
        alDarPorPerdida: datos.editable
            ? () => unawaited(_darPorPerdida(context, ref, datos.saldo))
            : null,
        // Solo la que se dio por perdida se puede reabrir: una pagada no se
        // "reabre", se le corrige el monto o se le borra el abono.
        alReabrir: datos.estado == EstadoDeudor.incobrable
            ? () => unawaited(_reabrir(context, ref))
            : null,
      ),
    );
  }
}
