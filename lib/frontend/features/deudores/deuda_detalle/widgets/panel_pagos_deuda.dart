import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/deudores/modelo/deudor_pago.dart';
import '../../../../../backend/share/dominio/metodo_pago.dart';
import '../../../../../core/formato.dart';
import '../../../../../core/resultado.dart';
import '../../../../share2/share2.dart';
import '../provider/deuda_editor_provider.dart';

/// La mitad de dinero de la ficha: contra qué se cobra, el formulario y lo que
/// ya se recibió.
///
/// **El contexto va arriba y no es decoración.** Registrar un abono es el
/// único gesto de esta pantalla que mueve plata, y quien lo hace está mirando
/// a un cliente al otro lado del mostrador: antes de teclear un monto tiene
/// que poder confirmar quién es y cuánto debía, sin volver al otro panel.
///
/// El formulario es el mismo de las reservas ([FormularioAbono]), con otras
/// palabras: se abona igual contra un apartado que contra un fiado.
class PanelPagosDeuda extends ConsumerWidget {
  const PanelPagosDeuda({super.key, required this.deudaId});

  final int deudaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = deudaEditorProvider(deudaId);
    final datos = ref.watch(
      provider.select((s) => (
            cliente: s.value?.deuda.nombreCliente ?? '',
            concepto: s.value?.deuda.concepto ?? '',
            total: s.value?.montoTotal ?? 0,
            saldo: s.value?.saldo ?? 0,
            editable: s.value?.editable ?? false,
          )),
    );

    Future<void> registrar(int monto, MetodoPago metodo, String? notas) async {
      final resultado = await ref.read(provider.notifier).registrarPago(
            monto: monto,
            metodoPago: metodo,
            notas: notas,
          );
      if (!context.mounted) return;
      switch (resultado) {
        case Fallo(:final mensaje):
          MensajeApp.error(context, mensaje);
        case Exito():
          MensajeApp.exito(context, 'Abono de ${formatearPrecio(monto)} '
              'registrado.');
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        _Contexto(
          cliente: datos.cliente,
          concepto: datos.concepto,
          total: datos.total,
        ),
        const SizedBox(height: 16),
        FormularioAbono<MetodoPago>(
          saldo: datos.saldo,
          habilitado: datos.editable,
          metodos: MetodoPago.paraAbonos,
          metodoInicial: MetodoPago.efectivo,
          constructorEtiqueta: (m) => m.etiqueta,
          formatearImporte: formatearPrecio,
          titulo: 'Registrar abono',
          etiquetaBoton: 'Registrar abono',
          etiquetaReferencia: 'Nota',
          placeholderReferencia: 'Opcional: recibo, quién recibió…',
          textoSaldado: 'No queda saldo: esta deuda ya está cobrada.',
          alRegistrar: (monto, metodo, nota) =>
              unawaited(registrar(monto, metodo, nota)),
        ),
        const SizedBox(height: 16),
        _Historial(deudaId: deudaId),
      ],
    );
  }
}

/// A quién se le fió y por qué.
class _Contexto extends StatelessWidget {
  const _Contexto({
    required this.cliente,
    required this.concepto,
    required this.total,
  });

  final String cliente;
  final String concepto;
  final int total;

  @override
  Widget build(BuildContext context) {
    return PanelSeccion(
      titulo: 'Le debe el taller a',
      icono: Icons.person_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FichaResumen(
            titulo: cliente.isEmpty ? 'Sin cliente' : cliente,
            subtitulo: concepto.isEmpty ? 'Sin concepto' : concepto,
            inicial: cliente.isEmpty ? null : inicialDe(cliente),
            icono: cliente.isEmpty ? Icons.person_outline : null,
          ),
          const SizedBox(height: 12),
          FilaDato(
            icono: Icons.sell_outlined,
            texto: 'Deuda total: ${formatearPrecio(total)}',
          ),
        ],
      ),
    );
  }
}

/// Lo que ya se cobró, en orden.
///
/// **Un abono se puede borrar y un movimiento de inventario no.** No es una
/// incoherencia: el libro mayor del stock refleja mercancía que se movió de
/// verdad, mientras que aquí un abono mal tecleado es solo eso, y dejarlo
/// obligaría a inventar un abono negativo para cuadrar. Al borrarlo, el
/// repositorio recalcula el caché y reabre la deuda si hacía falta.
class _Historial extends ConsumerWidget {
  const _Historial({required this.deudaId});

  final int deudaId;

  Future<void> _borrar(
    BuildContext context,
    WidgetRef ref,
    DeudorPago pago,
  ) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Borrar este abono?',
      mensaje: 'Se quitan ${formatearPrecio(pago.monto)} de lo cobrado y la '
          'deuda vuelve a quedar con ese saldo pendiente.',
    );
    if (confirmado != true || !context.mounted) return;

    final resultado =
        await ref.read(deudaEditorProvider(deudaId).notifier).eliminarPago(pago.id);
    if (!context.mounted) return;
    if (resultado case Fallo(:final mensaje)) MensajeApp.error(context, mensaje);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = deudaEditorProvider(deudaId);
    final pagos = ref.watch(
      provider.select((s) => s.value?.pagos ?? const <DeudorPago>[]),
    );
    final editable =
        ref.watch(provider.select((s) => s.value?.editable ?? false));

    return PanelSeccion(
      titulo: 'Abonos',
      icono: Icons.receipt_long_outlined,
      child: pagos.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Todavía no ha abonado nada.',
                style: TipografiaApp.caption,
              ),
            )
          : Column(
              children: [
                for (final pago in pagos)
                  FilaMovimiento(
                    key: ValueKey(pago.id),
                    icono: Icons.arrow_downward_rounded,
                    titulo: pago.metodoPago.etiqueta,
                    detalle: [
                      formatearFecha(pago.fechaPago),
                      if (pago.notas != null) pago.notas!,
                    ].join(' · '),
                    importe: formatearPrecio(pago.monto),
                    color: ColoresApp.statusSuccess,
                    alEliminar: editable
                        ? () => unawaited(_borrar(context, ref, pago))
                        : null,
                  ),
              ],
            ),
    );
  }
}
